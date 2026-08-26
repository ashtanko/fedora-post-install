#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
# shellcheck source=lib/config.bash
source "$CONFIG_HELPER" || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
load_config "$REPO_ROOT"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
# shellcheck source=lib/pkg.bash
source "$PKG_HELPER" || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }

echo "🚀 Installing AWS CLI v2 + Session Manager plugin..."

ARCH=$(rpm_arch)
case "$ARCH" in
    x86_64) SSM_ARCH="64bit" ;;
    aarch64) SSM_ARCH="arm64" ;;
esac

dnf_install curl unzip gnupg2

# --- AWS CLI v2 (official zip installer) ---
if command -v aws &>/dev/null; then
    echo "✅ aws already installed ($(aws --version 2>&1))"
else
    echo "📦 Installing the signature-verified AWS CLI v2 archive ($ARCH)..."
    FPI_AWS_INSTALL=1 bash "$REPO_ROOT/updates/update-aws-cli.sh"
    echo "✅ aws installed ($(aws --version 2>&1))"
fi

# --- Session Manager plugin (signature-verified RPM from Amazon S3) ---
if command -v session-manager-plugin &>/dev/null; then
    echo "✅ session-manager-plugin already installed"
else
    echo "📦 Downloading session-manager-plugin ($SSM_ARCH)..."
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    SSM_RPM="$TMP/session-manager-plugin.rpm"
    SSM_SIG="$SSM_RPM.sig"
    SSM_KEY="$TMP/session-manager-plugin.asc"
    SSM_GNUPGHOME="$TMP/gnupg"
    SSM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_${SSM_ARCH}/session-manager-plugin.rpm"
    SSM_KEY_FINGERPRINT="7959637124CE093AD501D47A2C4D4AFF6F6757EE"

    mkdir -m 700 "$SSM_GNUPGHOME"
    cat >"$SSM_KEY" <<'SSM_PUBLIC_KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mFIEZ5ERQxMIKoZIzj0DAQcCAwQjuZy+IjFoYg57sLTGhF3aZLBaGpzB+gY6j7Ix
P7NqbpXyjVj8a+dy79gSd64OEaMxUb7vw/jug+CfRXwVGRMNtIBBV1MgU1NNIFNl
c3Npb24gTWFuYWdlciA8c2Vzc2lvbi1tYW5hZ2VyLXBsdWdpbi1zaWduZXJAYW1h
em9uLmNvbT4gKEFXUyBTeXN0ZW1zIE1hbmFnZXIgU2Vzc2lvbiBNYW5hZ2VyIFBs
dWdpbiBMaW51eCBTaWduZXIgS2V5KYkBAAQQEwgAqAUCZ5ERQ4EcQVdTIFNTTSBT
ZXNzaW9uIE1hbmFnZXIgPHNlc3Npb24tbWFuYWdlci1wbHVnaW4tc2lnbmVyQGFt
YXpvbi5jb20+IChBV1MgU3lzdGVtcyBNYW5hZ2VyIFNlc3Npb24gTWFuYWdlciBQ
bHVnaW4gTGludXggU2lnbmVyIEtleSkWIQR5WWNxJM4JOtUB1HosTUr/b2dX7gIe
AwIbAwIVCAAKCRAsTUr/b2dX7rO1AQCa1kig3lQ78W/QHGU76uHx3XAyv0tfpE9U
oQBCIwFLSgEA3PDHt3lZ+s6m9JLGJsy+Cp5ZFzpiF6RgluR/2gA861M=
=2DQm
-----END PGP PUBLIC KEY BLOCK-----
SSM_PUBLIC_KEY
    gpg --batch --homedir "$SSM_GNUPGHOME" --import "$SSM_KEY"
    IMPORTED_FINGERPRINT=$(gpg --batch --homedir "$SSM_GNUPGHOME" --with-colons --fingerprint \
        | awk -F: '$1 == "fpr" { print toupper($10); exit }' | tr -d '[:space:]')
    if [ "$IMPORTED_FINGERPRINT" != "$SSM_KEY_FINGERPRINT" ]; then
        echo "❌ Session Manager signing key fingerprint mismatch: $IMPORTED_FINGERPRINT" >&2
        exit 1
    fi
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors -o "$SSM_RPM" "$SSM_URL"
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors -o "$SSM_SIG" "${SSM_URL}.sig"
    gpg --batch --homedir "$SSM_GNUPGHOME" --verify "$SSM_SIG" "$SSM_RPM"
    sudo dnf -q install -y --setopt=install_weak_deps=False "$SSM_RPM"
    echo "✅ session-manager-plugin installed"
fi

echo ""
echo "✅ AWS toolchain ready!"
echo "💡 Configure credentials: aws configure"
echo "💡 Start an SSM session:  aws ssm start-session --target i-xxxxxxxxxxxx"
