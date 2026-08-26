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

echo "🚀 Installing Cursor editor..."

# Cursor's official RPM repository publishes both x86_64 and aarch64 builds.
rpm_arch >/dev/null

# Remove only the user-local link created by this repository's former
# AppImage installer. The old AppImage is retained so no user data is deleted.
LEGACY_INSTALL_DIR="${CURSOR_INSTALL_DIR:-$HOME/.local/share/Cursor}"
LEGACY_LINK="$HOME/.local/bin/cursor"
LEGACY_DESKTOP="$HOME/.local/share/applications/cursor.desktop"
if [ -L "$LEGACY_LINK" ] \
    && [ "$(readlink -m "$LEGACY_LINK")" = "$(readlink -m "$LEGACY_INSTALL_DIR/Cursor.AppImage")" ]; then
    unlink "$LEGACY_LINK"
    echo "🔧 Removed the legacy Cursor AppImage command link"
fi
if [ -f "$LEGACY_DESKTOP" ] \
    && grep -Fqx "Exec=$LEGACY_INSTALL_DIR/Cursor.AppImage --no-sandbox %F" "$LEGACY_DESKTOP"; then
    unlink "$LEGACY_DESKTOP"
    echo "🔧 Removed the legacy Cursor AppImage desktop entry"
fi

if dnf_installed cursor; then
    echo "✅ Cursor is already installed through RPM"
    exit 0
fi

dnf_install curl gnupg2
echo "📦 Adding Cursor's signed RPM repository..."
repo_add cursor \
    "https://downloads.cursor.com/yumrepo" \
    "https://downloads.cursor.com/keys/anysphere.asc" \
    "380FF4BCDC34A4BD92A3565342A1772E62E492D6"

echo "📦 Installing Cursor..."
dnf_install cursor

if command -v cursor &>/dev/null; then
    echo "✅ Cursor installed successfully"
    echo "💡 Updates are delivered through the configured Cursor RPM repository and DNF."
else
    echo "❌ Cursor installation failed"
    exit 1
fi
