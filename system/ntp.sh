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

echo "🚀 Ensuring the system clock is time-synced..."

echo "📦 Ensuring Fedora's chrony package is installed..."
dnf_install chrony
for command_name in chronyd chronyc; do
    if ! command -v "$command_name" &>/dev/null; then
        echo "❌ $command_name is unavailable after installing chrony" >&2
        exit 1
    fi
done

SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"
if [ -d "$SYSTEMD_RUNTIME_DIR" ] && command -v systemctl &>/dev/null; then
    if systemctl is-enabled --quiet chronyd 2>/dev/null \
        && systemctl is-active --quiet chronyd 2>/dev/null; then
        echo "✅ chronyd already enabled and active"
    else
        echo "🔧 Enabling + starting chronyd..."
        sudo systemctl enable --now chronyd >/dev/null
    fi

    if ! systemctl is-active --quiet chronyd 2>/dev/null; then
        echo "❌ chronyd failed to start" >&2
        exit 1
    fi
else
    echo "💡 No systemd detected — chrony is installed but service management is left to your init system"
fi

echo ""
chronyc tracking 2>/dev/null | sed 's/^/   /' || true
