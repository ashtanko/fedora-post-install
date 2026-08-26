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

echo "🚀 Installing Warp terminal..."

# Warp publishes both x86_64 and aarch64 RPMs. Fail before repository changes
# if the shared helper cannot map the host architecture.
rpm_arch >/dev/null

echo "📦 Adding Warp GPG key and repository..."
repo_add warpdotdev \
    "https://releases.warp.dev/linux/rpm/stable" \
    "https://releases.warp.dev/linux/keys/warp.asc" \
    "0913165C78D5B7A41B42AC657FF7AB39D60F803F"

echo "📦 Installing Warp terminal..."
dnf_install warp-terminal

if command -v warp-terminal &>/dev/null; then
    echo "✅ Warp terminal installed successfully"
else
    echo "❌ Warp installation failed"
    exit 1
fi
