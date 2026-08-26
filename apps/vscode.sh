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

echo "🚀 Installing Visual Studio Code..."

echo "📦 Adding Microsoft GPG key and repository..."
repo_add vscode \
    "https://packages.microsoft.com/yumrepos/vscode" \
    "https://packages.microsoft.com/keys/microsoft.asc" \
    "BC528686B50D79E339D3721CEB3E94ADBE1229CF"

echo "📦 Installing VS Code..."
dnf_install code

if command -v code &>/dev/null; then
    echo "✅ VS Code installed ($(code --version | head -1))"
else
    echo "❌ VS Code installation failed"
    exit 1
fi
