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

echo "🚀 Configuring automatic DNF security updates..."

if [[ "${ENABLE_AUTO_UPDATES:-yes}" == "no" ]]; then
    echo "⏭️  Skipping auto-updates (ENABLE_AUTO_UPDATES=no)"
    exit 0
fi

DNF_MAJOR="$(dnf_major)"
if [[ "$DNF_MAJOR" == "5" ]]; then
    AUTOMATIC_PACKAGE="dnf5-plugin-automatic"
    AUTOMATIC_TIMER="dnf5-automatic.timer"
else
    AUTOMATIC_PACKAGE="dnf-automatic"
    AUTOMATIC_TIMER="dnf-automatic.timer"
fi

echo "📦 Ensuring $AUTOMATIC_PACKAGE is installed..."
dnf_install "$AUTOMATIC_PACKAGE"

# Underscored overrides are isolated regression-test seams, not user config.
AUTO_FILE="${_FPI_DNF_AUTOMATIC_CONFIG_FILE:-/etc/dnf/automatic.conf}"
DESIRED='[commands]
upgrade_type = security
download_updates = yes
apply_updates = yes
reboot = never

[emitters]
emit_via = stdio'

if [ -f "$AUTO_FILE" ] && printf '%s\n' "$DESIRED" | sudo cmp -s - "$AUTO_FILE"; then
    echo "✅ $AUTO_FILE already configured"
else
    echo "🔧 Writing $AUTO_FILE..."
    printf '%s\n' "$DESIRED" | sudo tee "$AUTO_FILE" > /dev/null
    if command -v restorecon &>/dev/null; then
        sudo restorecon "$AUTO_FILE"
    fi
fi

SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"
if [ -d "$SYSTEMD_RUNTIME_DIR" ] && command -v systemctl &>/dev/null; then
    if systemctl is-enabled --quiet "$AUTOMATIC_TIMER" 2>/dev/null; then
        echo "✅ $AUTOMATIC_TIMER already enabled"
    else
        echo "🔧 Enabling $AUTOMATIC_TIMER..."
        sudo systemctl enable --now "$AUTOMATIC_TIMER" >/dev/null
    fi
else
    echo "⚠️  No systemd — automatic updates are configured but $AUTOMATIC_TIMER was not enabled"
fi

echo ""
echo "✅ Auto-updates configured. Verify with:"
echo "     systemctl list-timers $AUTOMATIC_TIMER"
