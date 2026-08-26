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

echo "🚀 Installing Java (OpenJDK)..."

SUPPORTED_VERSIONS=(8 11 17 21 25)
DEFAULT_VERSION=21

if [[ -n "${JAVA_VERSION:-}" ]]; then
    VERSION="$JAVA_VERSION"
    echo "🔧 Using JAVA_VERSION=$VERSION from environment"
elif [[ -t 0 ]]; then
    echo "Which OpenJDK version?"
    echo "  1) 8  (LTS, legacy)"
    echo "  2) 11 (LTS)"
    echo "  3) 17 (LTS)"
    echo "  4) 21 (LTS, recommended)"
    echo "  5) 25 (current)"
    echo -n "Choice [4]: "
    read -r choice
    case "${choice:-4}" in
        1) VERSION=8 ;;
        2) VERSION=11 ;;
        3) VERSION=17 ;;
        4|"") VERSION=21 ;;
        5) VERSION=25 ;;
        *) echo "❌ Invalid choice: $choice"; exit 1 ;;
    esac
else
    VERSION="$DEFAULT_VERSION"
    echo "💡 No TTY and JAVA_VERSION unset — defaulting to OpenJDK $VERSION"
fi

valid=0
for v in "${SUPPORTED_VERSIONS[@]}"; do
    [[ "$VERSION" == "$v" ]] && { valid=1; break; }
done
if [[ $valid -eq 0 ]]; then
    echo "❌ Unsupported version: $VERSION (supported: ${SUPPORTED_VERSIONS[*]})"
    exit 1
fi

PKG="java-${VERSION}-openjdk-devel"

if dnf_installed "$PKG"; then
    echo "✅ $PKG already installed"
    java -version
    exit 0
fi

echo "📦 Installing $PKG..."
if ! dnf_install "$PKG"; then
    echo "❌ Fedora could not install $PKG"
    echo "💡 This Fedora release may not ship it. Try: dnf list --available 'java-*-openjdk-devel'"
    exit 1
fi

if command -v java &>/dev/null; then
    echo "✅ $PKG installed successfully"
    java -version
    echo "💡 If multiple JDKs are installed, switch defaults with:"
    echo "   sudo alternatives --config java"
    echo "   sudo alternatives --config javac"
else
    echo "❌ Java installation failed"
    exit 1
fi
