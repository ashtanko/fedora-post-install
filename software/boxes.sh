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

echo "🚀 Installing GNOME Boxes + virt-manager..."

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"
VIRTUALIZATION_PACKAGES=(
    gnome-boxes
    virt-manager
    qemu-kvm
    libvirt-daemon-kvm
    libvirt-daemon-config-network
    virt-install
)

packages_ready=true
for package in "${VIRTUALIZATION_PACKAGES[@]}"; do
    if ! dnf_installed "$package"; then
        packages_ready=false
        break
    fi
done

group_ready=false
if getent group libvirt &>/dev/null && id -nG "$TARGET_USER" | tr ' ' '\n' | grep -Fxq libvirt; then
    group_ready=true
fi

if [[ "$packages_ready" == true ]] \
    && systemctl is-enabled --quiet libvirtd.service \
    && systemctl is-active --quiet libvirtd.service \
    && [[ "$group_ready" == true ]]; then
    echo "✅ GNOME Boxes and the libvirt virtualization stack are already configured"
    exit 0
fi

if [[ "$packages_ready" != true ]]; then
    echo "📦 Installing Fedora's virtualization package group and GNOME Boxes..."
    dnf_group_install virtualization
    dnf_install gnome-boxes
fi

echo "🔧 Enabling libvirt..."
sudo systemctl enable --now libvirtd.service

if getent group libvirt &>/dev/null \
    && ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -Fxq libvirt; then
    sudo usermod -aG libvirt "$TARGET_USER"
    echo "⚠️ Log out and back in before using libvirt as $TARGET_USER"
fi

if sudo virsh --connect qemu:///system net-info default &>/dev/null; then
    sudo virsh --connect qemu:///system net-autostart default >/dev/null
    if ! sudo virsh --connect qemu:///system net-list --name | grep -Fxq default; then
        sudo virsh --connect qemu:///system net-start default >/dev/null
    fi
else
    echo "⚠️ libvirt's default NAT network is unavailable; create it in virt-manager before use"
fi

echo "✅ GNOME Boxes and virt-manager setup complete!"
