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

echo "🚀 Setting system hostname..."

CURRENT_HOSTNAME="$(hostname)"

# Resolve desired hostname: env var → interactive prompt (default: current)
DESIRED_HOSTNAME="${NEW_HOSTNAME:-}"
if [ -z "$DESIRED_HOSTNAME" ]; then
    if [ -t 0 ]; then
        echo -n "🖥️  Enter hostname [$CURRENT_HOSTNAME]: "
        read -r DESIRED_HOSTNAME
        DESIRED_HOSTNAME="${DESIRED_HOSTNAME:-$CURRENT_HOSTNAME}"
    else
        echo "⏭️  NEW_HOSTNAME not set and no TTY to prompt — skipping"
        exit 0
    fi
fi

# RFC 1123 label: letters, digits, hyphens; 1-63 chars; no leading/trailing hyphen
if ! [[ "$DESIRED_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    echo "❌ Invalid hostname: $DESIRED_HOSTNAME"
    exit 1
fi

if [ "$DESIRED_HOSTNAME" = "$CURRENT_HOSTNAME" ]; then
    echo "✅ Hostname already $CURRENT_HOSTNAME"
else
    echo "🔧 Setting hostname to $DESIRED_HOSTNAME..."
    if command -v hostnamectl &>/dev/null; then
        sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"
    else
        echo "$DESIRED_HOSTNAME" | sudo tee /etc/hostname >/dev/null
        sudo hostname "$DESIRED_HOSTNAME"
    fi
    if command -v restorecon &>/dev/null && [ -e /etc/hostname ]; then
        sudo restorecon /etc/hostname
    fi
    echo "✅ Hostname set to $DESIRED_HOSTNAME"
fi

# Fedora resolves the local hostname through systemd/nss-myhostname. The
# Debian-style 127.0.1.1 hosts entry is neither required nor added here.

echo "💡 Some apps only pick up the new hostname after a re-login or reboot."
