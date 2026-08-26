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

echo "🚀 Setting up browsers..."

ARCH="$(rpm_arch)"
if [ "$ARCH" != "x86_64" ]; then
    echo "❌ Google's Chrome RPM repository supports x86_64 only (detected: $ARCH)."
    exit 1
fi

# --- Google Chrome ---
echo "📦 Configuring Google's signed RPM repository..."
repo_add google-chrome \
    "https://dl.google.com/linux/chrome/rpm/stable/x86_64" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796"
dnf_install google-chrome-stable

if command -v google-chrome &>/dev/null; then
    echo "✅ Google Chrome installed ($(google-chrome --version))"
else
    echo "❌ Chrome installation failed"
    exit 1
fi
