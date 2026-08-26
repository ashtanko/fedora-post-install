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

echo "🚀 Installing Wireshark..."

# SUDO_USER preserves the desktop account when this script is accidentally
# launched through sudo; otherwise use the current account.
CURRENT_USER="${SUDO_USER:-${USER:-$(id -un)}}"

echo "📦 Installing Wireshark GUI and CLI packages..."
dnf_install wireshark wireshark-cli libcap shadow-utils

# Fedora's wireshark-cli RPM normally creates the group and ships dumpcap with
# these capabilities. Re-affirm both so the standalone script repairs a partial
# installation and remains useful if system/user-groups.sh was not selected.
if ! getent group wireshark >/dev/null 2>&1; then
    echo "🔧 Creating the wireshark system group..."
    sudo groupadd --system wireshark
fi

DUMPCAP_BIN=$(command -v dumpcap 2>/dev/null || true)
if [ -z "$DUMPCAP_BIN" ]; then
    echo "❌ dumpcap was not installed by wireshark-cli"
    exit 1
fi

echo "🔧 Configuring non-root packet capture..."
sudo chgrp wireshark "$DUMPCAP_BIN"
sudo chmod 0750 "$DUMPCAP_BIN"
sudo setcap cap_net_raw,cap_net_admin=eip "$DUMPCAP_BIN"

if [ "$(stat -c '%G' "$DUMPCAP_BIN")" != "wireshark" ] \
    || ! getcap "$DUMPCAP_BIN" | grep -Eq 'cap_net_(admin,cap_net_raw|raw,cap_net_admin)=eip'; then
    echo "❌ dumpcap capture permissions could not be configured"
    exit 1
fi

if id -nG "$CURRENT_USER" | tr ' ' '\n' | grep -qx wireshark; then
    echo "✅ $CURRENT_USER already in the wireshark group"
else
    echo "🔧 Adding $CURRENT_USER to the wireshark group..."
    sudo usermod -aG wireshark "$CURRENT_USER"
    echo "⚠️  Log out and back in (or run: newgrp wireshark) for capture permission to take effect"
fi

if ! command -v wireshark &>/dev/null || ! command -v tshark &>/dev/null; then
    echo "❌ Wireshark installation failed or its commands are not in PATH"
    exit 1
fi

echo ""
echo "✅ Wireshark installed!"
echo "💡 GUI: wireshark   •   headless capture/analysis: tshark"
echo "💡 List capturable interfaces without sudo: tshark -D"
