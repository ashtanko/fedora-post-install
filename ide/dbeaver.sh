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

echo "🚀 Installing DBeaver Community..."

# DBeaver publishes standalone RPMs but no RPM repository. Its official
# download page lists this Flathub application as the package-manager install.
DBEAVER_APP_ID="io.dbeaver.DBeaverCommunity"
if command -v flatpak &>/dev/null && flatpak info --user "$DBEAVER_APP_ID" &>/dev/null; then
    echo "✅ DBeaver Community is already installed"
    exit 0
fi

flatpak_install "$DBEAVER_APP_ID"

if flatpak info --user "$DBEAVER_APP_ID" &>/dev/null; then
    echo "✅ DBeaver Community installed successfully"
    echo "💡 Launch from the application menu, or run: flatpak run $DBEAVER_APP_ID"
    echo "💡 Updates are delivered through Flatpak."
else
    echo "❌ DBeaver installation failed"
    exit 1
fi
