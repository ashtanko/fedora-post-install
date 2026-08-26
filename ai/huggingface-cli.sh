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

echo "🚀 Installing Hugging Face CLI..."

find_hf() {
    if command -v hf &>/dev/null; then
        command -v hf
    elif [ -x "$HOME/.local/bin/hf" ]; then
        printf '%s\n' "$HOME/.local/bin/hf"
    else
        return 1
    fi
}

if HF_BIN=$(find_hf); then
    echo "✅ Hugging Face CLI already installed ($("$HF_BIN" version 2>/dev/null || echo 'version unknown'))"
    exit 0
fi

if ! command -v curl &>/dev/null || ! command -v python3 &>/dev/null; then
    echo "📦 Installing Fedora prerequisites for the Hugging Face installer..."
    dnf_install curl python3
fi

echo "📦 Downloading the official Hugging Face CLI installer..."
HF_INSTALLER=$(mktemp)
trap 'rm -f "$HF_INSTALLER"' EXIT
curl -fsSL --retry 3 --retry-all-errors \
    -o "$HF_INSTALLER" https://hf.co/cli/install.sh
bash "$HF_INSTALLER" --exclude-skill
rm -f "$HF_INSTALLER"
trap - EXIT

if ! HF_BIN=$(find_hf); then
    echo "❌ Hugging Face CLI installation failed or 'hf' is not in PATH" >&2
    exit 1
fi

echo "✅ Hugging Face CLI installed successfully ($("$HF_BIN" version 2>/dev/null || echo 'version unknown'))"
echo "💡 Run 'hf auth login' only if you need private or gated repositories"
