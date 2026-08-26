#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
[[ -r "$CONFIG_HELPER" ]] || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
# shellcheck source=../lib/config.bash
source "$CONFIG_HELPER"
load_config "$REPO_ROOT"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
[[ -r "$PKG_HELPER" ]] || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
# shellcheck source=../lib/pkg.bash
source "$PKG_HELPER"

echo "🚀 Installing VirtualBox..."

ARCH="$(rpm_arch)"
if [[ "$ARCH" != x86_64 ]]; then
    echo "❌ RPM Fusion's VirtualBox host packages support x86_64 only (detected $ARCH)" >&2
    exit 1
fi

INSTALL_VIRTUALBOX_EXTPACK="${INSTALL_VIRTUALBOX_EXTPACK:-no}"
case "$INSTALL_VIRTUALBOX_EXTPACK" in
    yes|no) ;;
    *)
        echo "❌ INSTALL_VIRTUALBOX_EXTPACK must be 'yes' or 'no'" >&2
        exit 2
        ;;
esac

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"
KERNEL_RELEASE="$(uname -r)"
RPMFUSION_KEY_URL="https://download1.rpmfusion.org/free/fedora/RPM-GPG-KEY-rpmfusion-free-fedora-2020"
RPMFUSION_KEY_FINGERPRINT="E9A491A3DE247814E7E067EAE06F8ECDD651FF2E"
# DNF expands these repository variables when it reads the generated files.
# shellcheck disable=SC2016
RPMFUSION_RELEASES_URL='https://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/'
# shellcheck disable=SC2016
RPMFUSION_UPDATES_URL='https://download1.rpmfusion.org/free/fedora/updates/$releasever/$basearch/'
AKMOD_CERT="/etc/pki/akmods/certs/public_key.der"

in_group() {
    local user="$1" group="$2"
    getent group "$group" &>/dev/null \
        && id -nG "$user" | tr ' ' '\n' | grep -Fxq "$group"
}

extension_pack_current() {
    local version="$1"
    VBoxManage list extpacks 2>/dev/null \
        | awk -v expected="$version" '
            $1 == "Name:" {
                oracle = ($0 ~ /^Name:[[:space:]]+Oracle VirtualBox Extension Pack[[:space:]]*$/)
            }
            oracle && $1 == "Version:" && $2 == expected { found = 1 }
            END { exit !found }
        '
}

VBOXMANAGE="$(command -v VBoxManage || true)"
if [[ -n "$VBOXMANAGE" ]] \
    && dnf_installed VirtualBox \
    && dnf_installed akmod-VirtualBox \
    && command -v modinfo &>/dev/null \
    && modinfo vboxdrv &>/dev/null \
    && in_group "$TARGET_USER" vboxusers; then
    VBOX_VERSION="$($VBOXMANAGE --version | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    if [[ "$INSTALL_VIRTUALBOX_EXTPACK" == no ]] \
        || extension_pack_current "$VBOX_VERSION"; then
        echo "✅ VirtualBox is already configured for kernel $KERNEL_RELEASE"
        exit 0
    fi
fi

if [[ -n "$VBOXMANAGE" ]] && ! dnf_installed VirtualBox; then
    echo "❌ A non-RPM-Fusion VirtualBox installation is already on PATH: $VBOXMANAGE" >&2
    echo "💡 Remove it before installing the RPM Fusion build to avoid package and module conflicts" >&2
    exit 1
fi

echo "📦 Installing kernel module build prerequisites..."
if ! dnf_install \
    "kernel-devel-$KERNEL_RELEASE" \
    kernel-headers \
    gcc \
    make \
    perl \
    elfutils-libelf-devel \
    akmods \
    mokutil; then
    echo "❌ Could not install kernel-devel for the running kernel: $KERNEL_RELEASE" >&2
    echo "💡 Apply Fedora updates, reboot into the latest kernel, and rerun this script" >&2
    exit 1
fi

SECURE_BOOT_ENABLED=false
if mokutil --sb-state 2>/dev/null | grep -Fqi 'SecureBoot enabled'; then
    SECURE_BOOT_ENABLED=true
    if [[ ! -f "$AKMOD_CERT" ]]; then
        echo "🔧 Generating the akmods module-signing key..."
        sudo kmodgenca -a
    fi
fi

echo "🔧 Configuring the signed RPM Fusion Free repositories..."
# RPM Fusion's own repository files disable metadata signatures while retaining
# mandatory RPM signature checks, so repo_gpgcheck intentionally matches upstream.
repo_add fedora-post-install-rpmfusion-free \
    "$RPMFUSION_RELEASES_URL" "$RPMFUSION_KEY_URL" "$RPMFUSION_KEY_FINGERPRINT" 0
repo_add fedora-post-install-rpmfusion-free-updates \
    "$RPMFUSION_UPDATES_URL" "$RPMFUSION_KEY_URL" "$RPMFUSION_KEY_FINGERPRINT" 0

echo "📦 Installing VirtualBox and its akmod..."
dnf_install VirtualBox akmod-VirtualBox

if getent group vboxusers &>/dev/null && ! in_group "$TARGET_USER" vboxusers; then
    sudo usermod -aG vboxusers "$TARGET_USER"
    echo "⚠️ Log out and back in before using USB devices in VirtualBox"
fi

echo "🔧 Building VirtualBox modules for kernel $KERNEL_RELEASE..."
if [[ "$SECURE_BOOT_ENABLED" == true ]]; then
    sudo akmods --force --rebuild --kernels "$KERNEL_RELEASE"
else
    sudo akmods --force --kernels "$KERNEL_RELEASE"
fi

if ! modinfo vboxdrv &>/dev/null; then
    echo "❌ The vboxdrv module was not built for kernel $KERNEL_RELEASE" >&2
    echo "💡 Inspect /var/cache/akmods/VirtualBox/ for the build log" >&2
    exit 1
fi

if [[ "$SECURE_BOOT_ENABLED" == true ]] && ! mokutil --test-key "$AKMOD_CERT" &>/dev/null; then
    cat >&2 <<EOF
⚠️ Secure Boot is enabled, but the akmods signing key is not enrolled yet.

Run:
  sudo mokutil --import $AKMOD_CERT

Choose a temporary password, reboot, select "Enroll MOK" in the firmware dialog,
confirm the enrollment with that password, reboot again, then rerun this script.
VirtualBox cannot load vboxdrv until that enrollment is complete.
EOF
    exit 1
fi

if ! lsmod | awk '$1 == "vboxdrv" { found = 1 } END { exit !found }'; then
    sudo modprobe vboxdrv
fi

if [[ "$INSTALL_VIRTUALBOX_EXTPACK" == yes ]]; then
    VBOXMANAGE="$(command -v VBoxManage || true)"
    [[ -n "$VBOXMANAGE" ]] || { echo "❌ VBoxManage was not installed" >&2; exit 1; }
    VBOX_VERSION="$($VBOXMANAGE --version | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"

    if extension_pack_current "$VBOX_VERSION"; then
        echo "✅ Oracle VirtualBox Extension Pack $VBOX_VERSION is already installed"
    else
        EXTPACK_ASSET="Oracle_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack"
        EXTPACK_BASE_URL="https://download.virtualbox.org/virtualbox/$VBOX_VERSION"
        TMP="$(mktemp --suffix=.vbox-extpack)"
        TMP_SUMS="$TMP.SHA256SUMS"
        trap 'rm -f "$TMP" "$TMP_SUMS"' EXIT

        echo "📦 Downloading Oracle VirtualBox Extension Pack $VBOX_VERSION..."
        curl -fsSL --retry 3 --retry-all-errors \
            -o "$TMP_SUMS" "$EXTPACK_BASE_URL/SHA256SUMS"
        curl -fsSL --retry 3 --retry-all-errors \
            -o "$TMP" "$EXTPACK_BASE_URL/$EXTPACK_ASSET"

        EXPECTED_SHA256="$(awk -v asset="$EXTPACK_ASSET" \
            '$2 == asset || $2 == "*" asset { print $1; exit }' "$TMP_SUMS")"
        ACTUAL_SHA256="$(sha256sum "$TMP" | awk '{ print $1 }')"
        if ! [[ "$EXPECTED_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] \
            || [[ "${ACTUAL_SHA256,,}" != "${EXPECTED_SHA256,,}" ]]; then
            echo "❌ Oracle Extension Pack checksum verification failed" >&2
            exit 1
        fi

        echo "⚠️ Oracle's PUEL license will be displayed and requires your explicit acceptance"
        sudo "$VBOXMANAGE" extpack install --replace "$TMP"
    fi
else
    echo "💡 Set INSTALL_VIRTUALBOX_EXTPACK=yes to install Oracle's optional PUEL-licensed Extension Pack"
fi

echo "✅ VirtualBox setup complete!"
