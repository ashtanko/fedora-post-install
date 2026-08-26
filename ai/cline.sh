#!/bin/bash
set -euo pipefail

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

echo "🚀 Installing Cline CLI..."

CLINE_VERSION="${CLINE_VERSION:-latest}"

if command -v cline &>/dev/null; then
    echo "✅ Cline CLI already installed ($(cline --version 2>/dev/null || echo 'version unknown'))"
    exit 0
fi

ensure_node_runtime 20.0.0

if ! NPM_PREFIX=$(PATH="$(dirname "$NODE_BIN"):$PATH" "$NPM_BIN" config get prefix) \
    || [ -z "$NPM_PREFIX" ]; then
    echo "❌ Could not determine npm's global install prefix" >&2
    exit 1
fi
CLINE_PACKAGE="cline@$CLINE_VERSION"
echo "📦 Installing $CLINE_PACKAGE..."
if [[ "$NPM_PREFIX" == "$HOME" || "$NPM_PREFIX" == "$HOME/"* ]] \
    || [ -w "$NPM_PREFIX" ] \
    || { [ ! -e "$NPM_PREFIX" ] && [ -w "$(dirname "$NPM_PREFIX")" ]; }; then
    PATH="$(dirname "$NODE_BIN"):$PATH" "$NPM_BIN" install -g "$CLINE_PACKAGE"
else
    sudo env PATH="$(dirname "$NODE_BIN"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        "$NPM_BIN" install -g "$CLINE_PACKAGE"
fi

if ! command -v cline &>/dev/null; then
    echo "❌ Cline CLI installation failed or 'cline' is not in PATH" >&2
    exit 1
fi

echo "✅ Cline CLI installed successfully ($(cline --version 2>/dev/null || echo 'version unknown'))"
echo "💡 Run 'cline auth' to select and authenticate a model provider"
