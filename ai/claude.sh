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

echo "🚀 Installing Claude Code CLI..."

CLAUDE_CHANNEL="${CLAUDE_CHANNEL:-stable}"
case "$CLAUDE_CHANNEL" in
    stable|latest) ;;
    *)
        echo "❌ Unsupported CLAUDE_CHANNEL: $CLAUDE_CHANNEL (expected stable or latest)" >&2
        exit 2
        ;;
esac

rpm_arch >/dev/null
dnf_install curl gnupg2

echo "📦 Configuring Anthropic's signed Claude Code RPM repository..."
repo_add claude-code \
    "https://downloads.claude.ai/claude-code/rpm/$CLAUDE_CHANNEL" \
    'https://downloads.claude.ai/keys/claude-code.asc' \
    '31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE'

if dnf_installed claude-code && command -v claude &>/dev/null; then
    echo "✅ Claude Code already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
    echo "💡 Update it later with: bash updates/update-claude.sh"
    exit 0
fi

echo "📦 Installing Claude Code from the ${CLAUDE_CHANNEL} channel..."
dnf_install claude-code

if ! command -v claude &>/dev/null; then
    echo "❌ Claude Code installation failed or 'claude' is not in PATH" >&2
    exit 1
fi

echo "✅ Claude Code installed successfully ($(claude --version 2>/dev/null || echo 'version unknown'))"
echo "💡 Next step: run 'claude' and follow the browser sign-in prompts"
