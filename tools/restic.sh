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

echo "🚀 Installing restic (deduplicated, encrypted backups)..."

# Complements tools/backup-home.sh (full tarball snapshots) with incremental,
# versioned ones, and speaks rclone remotes natively (tools/rclone.sh).
if command -v restic &>/dev/null; then
    echo "✅ restic already installed ($(restic version 2>/dev/null | head -1))"
    echo "💡 Updates are managed through DNF"
    exit 0
fi

echo "📦 Installing Fedora's restic package..."
dnf_install restic

if ! command -v restic &>/dev/null; then
    echo "❌ restic installation failed or is not in PATH"
    exit 1
fi

echo ""
echo "✅ restic installed ($(restic version 2>/dev/null | head -1))"
echo "💡 Initialize a local repo:   restic init --repo ~/backups/restic"
echo "💡 Back up your home:         restic -r ~/backups/restic backup ~/Documents"
echo "💡 Straight to an rclone remote (see tools/rclone.sh):"
echo "     restic -r rclone:remote:backups init"
echo "💡 Prune old snapshots:       restic -r <repo> forget --keep-daily 7 --keep-weekly 4 --prune"
