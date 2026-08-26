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

echo "🚀 Installing Google Cloud CLI..."

GCLOUD_ARCH=$(rpm_arch)
GCLOUD_REPO="https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-${GCLOUD_ARCH}"

dnf_install curl gnupg2 libxcrypt-compat

# Google documents repo_gpgcheck=0 for this repository. Package signatures
# remain mandatory (gpgcheck=1), and repo_add pins the published package key.
repo_add google-cloud-sdk "$GCLOUD_REPO" \
    'https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg' \
    '3749E1BA95A86CE054546ED2F09C394C3E1BA8D5' 0

if dnf_installed google-cloud-cli && command -v gcloud &>/dev/null; then
    echo "✅ gcloud already installed ($(gcloud --version 2>/dev/null | head -1))"
else
    echo "📦 Installing google-cloud-cli..."
    dnf_install google-cloud-cli
    echo "✅ gcloud installed ($(gcloud --version 2>/dev/null | head -1))"
fi

# gke-gcloud-auth-plugin is what makes `kubectl` able to auth against GKE
# clusters — natural pairing with dev/kubernetes.sh.
if command -v gke-gcloud-auth-plugin &>/dev/null; then
    echo "✅ gke-gcloud-auth-plugin already installed"
else
    echo "📦 Installing gke-gcloud-auth-plugin (for kubectl + GKE)..."
    dnf_install google-cloud-cli-gke-gcloud-auth-plugin
fi

echo ""
echo "✅ Google Cloud CLI ready!"
echo "💡 Authenticate:        gcloud auth login"
echo "💡 Set a project:       gcloud config set project <project-id>"
echo "💡 kubectl for GKE:     gcloud container clusters get-credentials <cluster> --zone <zone>"
