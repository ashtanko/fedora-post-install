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

echo "🚀 Installing rclone (cloud storage sync)..."

if command -v rclone &>/dev/null; then
    echo "✅ rclone already installed ($(rclone version 2>/dev/null | head -1))"
else
    # Fedora tracks rclone closely, so prefer its signed repository package to
    # a mutable upstream installer. DNF owns future updates as well.
    echo "📦 Installing Fedora's rclone package..."
    dnf_install rclone

    if ! command -v rclone &>/dev/null; then
        echo "❌ rclone installation failed or is not in PATH"
        exit 1
    fi
    echo "✅ rclone installed ($(rclone version 2>/dev/null | head -1))"
fi

echo ""
echo "✅ rclone ready!"
echo "💡 Complements tools/backup-home.sh: add a remote, then sync the backup dir offsite."
echo "💡 Configure a remote (interactive):  rclone config"
echo "💡 Example offsite copy:              rclone copy \"\$BACKUP_DIR\" remote:backups"
