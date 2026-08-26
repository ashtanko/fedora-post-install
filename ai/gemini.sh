#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
NODE_HELPER="$REPO_ROOT/lib/node.bash"
# shellcheck source=lib/config.bash
source "$CONFIG_HELPER" || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
# shellcheck source=lib/pkg.bash
source "$PKG_HELPER" || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
# shellcheck source=lib/node.bash
source "$NODE_HELPER" || { echo "❌ Missing Node.js helper: $NODE_HELPER" >&2; exit 1; }
load_config "$REPO_ROOT"

echo "🚀 Installing Gemini CLI..."

ensure_node_runtime 18.0.0
echo "✅ Node.js $("$NODE_BIN" --version) found"

if ! NPM_PREFIX=$("$NPM_BIN" config get prefix) || [ -z "$NPM_PREFIX" ]; then
    echo "❌ Could not determine npm's global install prefix"
    exit 1
fi

# Install Gemini CLI globally
if command -v gemini &>/dev/null; then
    echo "✅ Gemini CLI already installed ($(gemini --version 2>/dev/null || echo 'version unknown'))"
    echo "💡 Update with: bash updates/update-gemini.sh"
    exit 0
fi

echo "📦 Installing @google/gemini-cli..."
if [[ "$NPM_PREFIX" == "$HOME" || "$NPM_PREFIX" == "$HOME/"* ]] \
    || [ -w "$NPM_PREFIX" ] \
    || { [ ! -e "$NPM_PREFIX" ] && [ -w "$(dirname "$NPM_PREFIX")" ]; }; then
    "$NPM_BIN" install -g @google/gemini-cli
else
    sudo "$NPM_BIN" install -g @google/gemini-cli
fi

if command -v gemini &>/dev/null; then
    echo "✅ Gemini CLI installed successfully!"
    echo ""
    echo "💡 Next step: run 'gemini' to authenticate via your Google account"
else
    echo "❌ Installation failed or 'gemini' is not in PATH"
    exit 1
fi
