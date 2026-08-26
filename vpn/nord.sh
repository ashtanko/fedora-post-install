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

echo "🚀 Installing NordVPN..."

ARCH="$(rpm_arch)"
USERNAME="${USER:-$(id -un)}"
SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"

dnf_install curl gnupg2

echo "📦 Configuring NordVPN's signed RPM repository..."
repo_add nordvpn \
    "https://repo.nordvpn.com/yum/nordvpn/centos/$ARCH" \
    'https://repo.nordvpn.com/gpg/nordvpn_public.asc' \
    'BC5480EFEC5C081CE5BCFBE26B219E535C964CA1'

if dnf_installed nordvpn && command -v nordvpn &>/dev/null; then
    echo "✅ NordVPN already installed ($(nordvpn --version 2>/dev/null | head -1))"
else
    echo "📦 Installing NordVPN..."
    dnf_install nordvpn

    if ! command -v nordvpn &>/dev/null; then
        echo "❌ NordVPN installation failed or 'nordvpn' is not in PATH"
        exit 1
    fi
    echo "✅ NordVPN installed ($(nordvpn --version 2>/dev/null | head -1))"
fi

if [ -d "$SYSTEMD_RUNTIME_DIR" ] && command -v systemctl &>/dev/null; then
    echo "🔧 Enabling the NordVPN daemon..."
    sudo systemctl enable --now nordvpnd.socket nordvpnd.service
else
    echo "⚠️  systemd is not running; NordVPN was installed but nordvpnd was not started"
fi

# Add current user to nordvpn group (needed for non-root CLI access)
if getent group nordvpn >/dev/null 2>&1; then
    if groups "$USERNAME" | grep -qw nordvpn; then
        echo "✅ User already in nordvpn group"
    else
        echo "👤 Adding $USERNAME to nordvpn group..."
        sudo usermod -aG nordvpn "$USERNAME"
        echo "⚠️  Log out and back in (or run: newgrp nordvpn) for group membership to take effect"
    fi
else
    echo "⚠️  nordvpn group does not exist — installer may have changed; check 'getent group nordvpn'"
fi

echo ""
echo "✅ NordVPN setup complete!"
echo "💡 Next step: run 'nordvpn login' and follow the browser prompt."
echo "💡 Then try: nordvpn connect"
