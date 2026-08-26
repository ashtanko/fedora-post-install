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
echo "🚀 Installing just (command runner)..."

if command -v just &>/dev/null; then
    echo "✅ just already installed ($(just --version 2>/dev/null | head -1))"
    exit 0
fi

echo "📦 Installing just from Fedora..."
dnf_install just
if ! command -v just &>/dev/null; then
    echo "❌ just installation failed or is not in PATH"
    exit 1
fi

echo ""
echo "✅ just installed ($(just --version 2>/dev/null | head -1))"
echo "💡 Create a justfile, then run recipes by name: just build"
echo "💡 List available recipes: just --list"
