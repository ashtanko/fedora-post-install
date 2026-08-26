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

echo "🚀 Installing .NET SDK..."

DOTNET_VERSION="${DOTNET_VERSION:-8.0}"
SDK_PACKAGE="dotnet-sdk-${DOTNET_VERSION}"

if command -v dotnet &>/dev/null && dotnet --list-sdks 2>/dev/null | grep -q "^${DOTNET_VERSION}\."; then
    echo "✅ .NET SDK $DOTNET_VERSION already installed"
    dotnet --list-sdks | sed 's/^/   /'
    exit 0
fi

echo "📦 Installing Fedora's $SDK_PACKAGE..."
if ! dnf_install "$SDK_PACKAGE"; then
    echo "❌ Fedora could not install $SDK_PACKAGE"
    echo "💡 List available SDKs with: dnf list --available 'dotnet-sdk-*'"
    exit 1
fi

if ! dotnet --list-sdks 2>/dev/null | grep -q "^${DOTNET_VERSION}\."; then
    echo "❌ $SDK_PACKAGE installed but dotnet does not report SDK $DOTNET_VERSION"
    exit 1
fi

echo ""
echo "✅ .NET SDK installed!"
dotnet --list-sdks | sed 's/^/   /'
echo "💡 Install a different major version: DOTNET_VERSION=9.0 bash dev/dotnet.sh"
