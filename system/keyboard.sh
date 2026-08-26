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

echo "🚀 Setting up keyboard remapping with keyd..."

# Underscored overrides are isolated regression-test seams, not user config.
KEYD_DIR="${_FPI_KEYD_CONFIG_DIR:-/etc/keyd}"
KEYD_CONF="$KEYD_DIR/default.conf"
UINPUT_DEVICE="${_FPI_UINPUT_DEVICE:-/dev/uinput}"

SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"
if [ ! -d "$SYSTEMD_RUNTIME_DIR" ] || ! command -v systemctl &>/dev/null; then
    echo "❌ keyd requires a running systemd instance" >&2
    exit 1
fi

# keyd is not in Fedora's main repositories. alternateved/keyd is a maintained
# third-party COPR with current Fedora builds; enabling it is an explicit trust
# decision made only when this selected script actually needs to install keyd.
if ! command -v keyd &>/dev/null; then
    echo "📦 Enabling the third-party alternateved/keyd COPR..."
    copr_enable alternateved/keyd
    dnf_install keyd
else
    echo "✅ keyd already installed"
fi
if ! command -v keyd &>/dev/null; then
    echo "❌ keyd command is unavailable after installation" >&2
    exit 1
fi

if [ ! -e "$UINPUT_DEVICE" ]; then
    echo "🔧 Loading the uinput kernel module required by keyd..."
    if command -v modprobe &>/dev/null; then
        sudo modprobe uinput || true
    fi
fi
if [ ! -e "$UINPUT_DEVICE" ]; then
    echo "❌ $UINPUT_DEVICE is unavailable; keyd cannot inject remapped input events" >&2
    exit 1
fi

# Expected config content
read -r -d '' KEYD_CONFIG <<'EOF' || true
[ids]
*

[main]
# Left Alt → Left Ctrl (macOS-style)
leftalt = leftcontrol

# Left Ctrl → Meta (Cmd key)
leftcontrol = leftmeta
EOF

# Only write if config doesn't already match
sudo mkdir -p "$KEYD_DIR"
CONFIG_CHANGED=0
if [ -f "$KEYD_CONF" ] && printf '%s\n' "$KEYD_CONFIG" | sudo cmp -s - "$KEYD_CONF"; then
    echo "✅ keyd config already up to date"
else
    echo "⌨️  Writing keyd config (macOS-style: Left Alt → Ctrl, Left Ctrl → Meta)..."
    printf '%s\n' "$KEYD_CONFIG" | sudo tee "$KEYD_CONF" > /dev/null
    CONFIG_CHANGED=1
fi
if command -v restorecon &>/dev/null; then
    sudo restorecon -R "$KEYD_DIR"
fi

if ! systemctl is-enabled --quiet keyd 2>/dev/null; then
    echo "🔧 Enabling keyd service..."
    sudo systemctl enable keyd >/dev/null
fi

if systemctl is-active --quiet keyd 2>/dev/null; then
    if [ "$CONFIG_CHANGED" -eq 1 ]; then
        echo "🔄 Restarting keyd service..."
        sudo systemctl restart keyd
    fi
else
    echo "🔧 Starting keyd service..."
    sudo systemctl start keyd
fi

# Verify
if systemctl is-active --quiet keyd; then
    echo "✅ keyd is running"
else
    echo "❌ keyd failed to start; inspect: sudo journalctl -u keyd -b" >&2
    if command -v ausearch &>/dev/null; then
        echo "💡 Check SELinux denials with: sudo ausearch -m AVC -ts recent" >&2
    fi
    exit 1
fi
