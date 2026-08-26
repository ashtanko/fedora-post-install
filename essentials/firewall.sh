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

echo "🚀 Configuring firewalld..."

if [[ "${ENABLE_FIREWALL:-yes}" == "no" ]]; then
    echo "⏭️  Skipping firewalld (ENABLE_FIREWALL=no)"
    exit 0
fi

# Underscored override is an isolated regression-test seam, not user config.
SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"
if [ ! -d "$SYSTEMD_RUNTIME_DIR" ] || ! command -v systemctl &>/dev/null; then
    echo "❌ firewalld requires a running systemd instance" >&2
    exit 1
fi

echo "📦 Ensuring firewalld is installed..."
dnf_install firewalld

if systemctl is-active --quiet firewalld 2>/dev/null; then
    FIREWALL_ACTIVE=1
    echo "✅ firewalld already active"
else
    FIREWALL_ACTIVE=0
fi

if [[ "$FIREWALL_ACTIVE" == "1" ]]; then
    FIREWALL_ZONE="${FIREWALL_ZONE:-$(sudo firewall-cmd --get-default-zone)}"
    AVAILABLE_ZONES="$(sudo firewall-cmd --get-zones)"
else
    # Configure the permanent zone before starting firewalld, so enabling the
    # firewall cannot strand a machine that is currently reached over SSH.
    FIREWALL_ZONE="${FIREWALL_ZONE:-$(sudo firewall-offline-cmd --get-default-zone)}"
    AVAILABLE_ZONES="$(sudo firewall-offline-cmd --get-zones)"
fi

if ! [[ "$FIREWALL_ZONE" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "❌ Invalid firewalld zone: $FIREWALL_ZONE" >&2
    exit 1
fi
if ! printf '%s\n' "$AVAILABLE_ZONES" | tr ' ' '\n' | grep -Fxq "$FIREWALL_ZONE"; then
    echo "❌ Unknown firewalld zone: $FIREWALL_ZONE" >&2
    exit 1
fi

# Preserve the machine's existing zone policy and services. Only ensure SSH is
# reachable before leaving the firewall enabled, so remote sessions stay safe.
if [[ "$FIREWALL_ACTIVE" == "1" ]]; then
    if sudo firewall-cmd --permanent --zone="$FIREWALL_ZONE" --query-service=ssh >/dev/null; then
        echo "✅ SSH already allowed permanently in zone $FIREWALL_ZONE"
    else
        echo "🔧 Allowing SSH permanently in zone $FIREWALL_ZONE..."
        sudo firewall-cmd --permanent --zone="$FIREWALL_ZONE" --add-service=ssh >/dev/null
        sudo firewall-cmd --reload >/dev/null
    fi
else
    if sudo firewall-offline-cmd --zone="$FIREWALL_ZONE" --query-service=ssh >/dev/null; then
        echo "✅ SSH already allowed permanently in zone $FIREWALL_ZONE"
    else
        echo "🔧 Allowing SSH permanently in zone $FIREWALL_ZONE before activation..."
        sudo firewall-offline-cmd --zone="$FIREWALL_ZONE" --add-service=ssh >/dev/null
    fi
    echo "🔧 Enabling + starting firewalld..."
    sudo systemctl enable --now firewalld >/dev/null
fi

if ! sudo firewall-cmd --zone="$FIREWALL_ZONE" --query-service=ssh >/dev/null; then
    sudo firewall-cmd --zone="$FIREWALL_ZONE" --add-service=ssh >/dev/null
fi

echo ""
echo "✅ firewalld is active; current $FIREWALL_ZONE zone:"
sudo firewall-cmd --zone="$FIREWALL_ZONE" --list-all
