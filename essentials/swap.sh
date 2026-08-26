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

echo "🚀 Configuring swap..."

SWAP_FILE="${SWAP_FILE:-/swapfile}"
FSTAB_FILE="${FSTAB_FILE:-/etc/fstab}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-4}"
ENABLE_DISK_SWAP="${ENABLE_DISK_SWAP:-no}"

# Skip if any swap is already active (file or partition)
if [ "$(swapon --show --noheadings 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "✅ Swap already active:"
    swapon --show
    exit 0
fi

case "$ENABLE_DISK_SWAP" in
    yes) ;;
    no)
        echo "⏭️  No swap is active, but disk swap is opt-in on Fedora (ENABLE_DISK_SWAP=no)"
        echo "💡 Fedora Workstation normally provides compressed swap through zram."
        exit 0
        ;;
    *)
        echo "❌ ENABLE_DISK_SWAP must be yes or no — got '$ENABLE_DISK_SWAP'" >&2
        exit 1
        ;;
esac

if ! [[ "$SWAP_SIZE_GB" =~ ^[1-9][0-9]*$ ]]; then
    echo "❌ SWAP_SIZE_GB must be a positive integer — got '$SWAP_SIZE_GB'" >&2
    exit 1
fi

if [ -f "$SWAP_FILE" ]; then
    echo "⚠️  $SWAP_FILE exists but is not active — enabling it"
    sudo swapon "$SWAP_FILE"
else
    echo "📦 Creating ${SWAP_SIZE_GB}G swap file at $SWAP_FILE..."
    SWAP_FILESYSTEM="$(findmnt -n -o FSTYPE --target "$(dirname "$SWAP_FILE")" 2>/dev/null || true)"
    if [[ "$SWAP_FILESYSTEM" == "btrfs" ]]; then
        echo "🔧 Creating a Btrfs-compatible swap file..."
        if ! command -v btrfs &>/dev/null; then
            dnf_install btrfs-progs
        fi
        sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE_GB}G" "$SWAP_FILE"
    else
        sudo fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE"
        sudo chmod 600 "$SWAP_FILE"
        sudo mkswap "$SWAP_FILE"
    fi
    if command -v restorecon &>/dev/null; then
        sudo restorecon "$SWAP_FILE"
    fi
    sudo swapon "$SWAP_FILE"
fi

# Persist across reboots
if ! awk -v swap_file="$SWAP_FILE" \
    '$1 == swap_file && $2 == "none" && $3 == "swap" { found = 1 } END { exit !found }' \
    "$FSTAB_FILE"; then
    echo "${SWAP_FILE} none swap sw 0 0" | sudo tee -a "$FSTAB_FILE" > /dev/null
    if command -v restorecon &>/dev/null; then
        sudo restorecon "$FSTAB_FILE"
    fi
    echo "✅ Added $SWAP_FILE to $FSTAB_FILE"
fi

echo ""
echo "✅ Swap is active:"
swapon --show
echo "💡 Tune swappiness with: echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf"
