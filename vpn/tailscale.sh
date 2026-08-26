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

echo "🚀 Installing Tailscale..."

rpm_arch >/dev/null
SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"
TAILSCALED_RUNNING=no

dnf_install curl gnupg2

echo "📦 Configuring Tailscale's signed Fedora repository..."
repo_add tailscale-stable \
    "https://pkgs.tailscale.com/stable/fedora/\$basearch" \
    'https://pkgs.tailscale.com/stable/fedora/repo.gpg' \
    '2596A99EAAB33821893C0A79458CA832957F5868'

if dnf_installed tailscale && command -v tailscale &>/dev/null; then
    echo "✅ Tailscale already installed ($(tailscale version 2>/dev/null | head -1))"
else
    echo "📦 Installing Tailscale..."
    dnf_install tailscale

    if ! command -v tailscale &>/dev/null; then
        echo "❌ Tailscale installation failed or 'tailscale' is not in PATH"
        exit 1
    fi
    echo "✅ Tailscale installed ($(tailscale version 2>/dev/null | head -1))"
fi

if [ -d "$SYSTEMD_RUNTIME_DIR" ] && command -v systemctl &>/dev/null; then
    if systemctl is-active --quiet tailscaled.service 2>/dev/null; then
        echo "✅ tailscaled is running"
    else
        echo "🔧 Starting tailscaled..."
        sudo systemctl enable --now tailscaled.service
    fi
    TAILSCALED_RUNNING=yes
else
    echo "⚠️  systemd is not running; Tailscale was installed but tailscaled was not started"
fi

echo ""
if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    if [ "$TAILSCALED_RUNNING" = yes ]; then
        echo "🔑 TAILSCALE_AUTHKEY is set — authenticating non-interactively..."
        sudo tailscale up --auth-key="$TAILSCALE_AUTHKEY"
        echo "✅ Connected: $(tailscale ip -4 2>/dev/null || echo 'pending')"
    else
        echo "⚠️  TAILSCALE_AUTHKEY was not used because tailscaled is not running"
        echo "💡 Start tailscaled, then rerun this script to authenticate non-interactively."
    fi
else
    echo "✅ Tailscale setup complete!"
    echo "💡 Next step: run 'sudo tailscale up' and follow the browser login prompt."
    echo "💡 Or set TAILSCALE_AUTHKEY in .env to authenticate non-interactively next run."
fi
