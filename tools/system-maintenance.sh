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

# One-shot disk-cleanup pass. Safe to run repeatedly.

echo "🚀 System maintenance pass..."

human_size() {
    df --output=avail -BG / | tail -1 | tr -d 'G '
}
BEFORE=$(human_size)

echo ""
echo "📦 DNF: removing orphaned dependencies..."
sudo dnf -q autoremove -y

echo ""
echo "📦 DNF: cleaning package caches..."
sudo dnf clean all

echo ""
echo "📰 systemd journal: vacuuming logs older than 7 days..."
sudo journalctl --vacuum-time=7d

if command -v docker &>/dev/null; then
    echo ""
    echo "🐳 docker: pruning dangling images, stopped containers, build cache..."
    docker system prune -f || true
fi

if command -v flatpak &>/dev/null; then
    echo ""
    echo "📦 flatpak: removing unused runtimes..."
    flatpak uninstall --unused -y || true
fi

# User-level caches that bloat over months
echo ""
echo "🧹 Trimming bloated user caches..."
for d in "$HOME/.cache/thumbnails" "$HOME/.cache/yarn" "$HOME/.cache/pip" "$HOME/.npm/_cacache"; do
    if [ -d "$d" ]; then
        SIZE=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
        rm -rf "$d"
        echo "  ✅ Cleared $d ($SIZE)"
    fi
done

AFTER=$(human_size)
DELTA=$((AFTER - BEFORE))

echo ""
echo "✅ Done. Free space: ${BEFORE}G → ${AFTER}G (Δ ${DELTA}G)"
df -hT / | sed 's/^/   /'
