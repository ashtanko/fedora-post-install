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

echo "🚀 Installing MCP Inspector..."

MCP_INSPECTOR_VERSION="${MCP_INSPECTOR_VERSION:-latest}"

if command -v mcp-inspector &>/dev/null; then
    echo "✅ MCP Inspector already installed"
    exit 0
fi

ensure_node_runtime 22.19.0

if ! NPM_PREFIX=$(PATH="$(dirname "$NODE_BIN"):$PATH" "$NPM_BIN" config get prefix) \
    || [ -z "$NPM_PREFIX" ]; then
    echo "❌ Could not determine npm's global install prefix" >&2
    exit 1
fi
INSPECTOR_PACKAGE="@modelcontextprotocol/inspector@$MCP_INSPECTOR_VERSION"
echo "📦 Installing $INSPECTOR_PACKAGE..."
if [[ "$NPM_PREFIX" == "$HOME" || "$NPM_PREFIX" == "$HOME/"* ]] \
    || [ -w "$NPM_PREFIX" ] \
    || { [ ! -e "$NPM_PREFIX" ] && [ -w "$(dirname "$NPM_PREFIX")" ]; }; then
    PATH="$(dirname "$NODE_BIN"):$PATH" "$NPM_BIN" install -g "$INSPECTOR_PACKAGE"
else
    sudo env PATH="$(dirname "$NODE_BIN"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        "$NPM_BIN" install -g "$INSPECTOR_PACKAGE"
fi

if ! command -v mcp-inspector &>/dev/null; then
    echo "❌ MCP Inspector installation failed or 'mcp-inspector' is not in PATH" >&2
    exit 1
fi

echo "✅ MCP Inspector installed successfully"
echo "💡 Run 'mcp-inspector <server-command>' to inspect a local MCP server"
