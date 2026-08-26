#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
# shellcheck source=lib/config.bash
source "$CONFIG_HELPER" || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
# shellcheck source=lib/pkg.bash
source "$PKG_HELPER" || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
load_config "$REPO_ROOT"

echo "🚀 Installing Antigravity..."

rpm_arch >/dev/null
dnf_install curl gnupg2

echo "📦 Configuring Google's Antigravity RPM repository..."
# Google Artifact Registry does not support DNF metadata GPG checking. The
# Antigravity RPM itself is signed by a subkey of Google's pinned Linux key,
# so package signature checking stays enabled while repo_gpgcheck is disabled.
repo_add antigravity-rpm \
    'https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm' \
    'https://dl.google.com/linux/linux_signing_key.pub' \
    'EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796' \
    0

if dnf_installed antigravity; then
    echo "✅ Antigravity already installed ($(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' antigravity))"
    echo "💡 Update it later with: bash updates/update-antigravity.sh"
    exit 0
fi

echo "📦 Installing Antigravity..."
dnf_install antigravity

if ! dnf_installed antigravity; then
    echo "❌ Antigravity installation failed" >&2
    exit 1
fi

echo "✅ Antigravity installed successfully ($(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' antigravity))"
echo "💡 Launch it from the app grid or run 'antigravity'; sign in with a Google account on first start"
echo "💡 Later upgrades: bash updates/update-antigravity.sh (or the normal DNF upgrade cycle)"
