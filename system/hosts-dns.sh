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

echo "🚀 Configuring DNS resolvers..."

# Fedora Workstation normally lets NetworkManager own DNS. Only modify
# systemd-resolved when the machine has already chosen and activated it; never
# enable a second resolver stack or rewrite NetworkManager connection profiles.
SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"
if [ ! -d "$SYSTEMD_RUNTIME_DIR" ] || ! command -v systemctl &>/dev/null; then
    echo "⏭️  systemd is not active — leaving the existing resolver setup unchanged"
    exit 0
fi

if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    if command -v nmcli &>/dev/null; then
        echo "⏭️  NetworkManager is managing DNS — leaving active connection profiles unchanged"
    else
        echo "⏭️  systemd-resolved is not active — leaving the existing resolver setup unchanged"
    fi
    exit 0
fi

if ! command -v resolvectl &>/dev/null; then
    echo "❌ systemd-resolved is active but resolvectl is unavailable" >&2
    exit 1
fi

DNS_SERVERS="${DNS_SERVERS:-1.1.1.1 9.9.9.9}"
DNS_FALLBACK_SERVERS="${DNS_FALLBACK_SERVERS:-1.0.0.1 149.112.112.112}"

validate_dns_list() {
    local name="$1" value="$2" allow_empty="$3" server
    local -a servers=()

    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
        echo "❌ $name must be a single space-separated line of IP addresses" >&2
        return 1
    fi
    read -ra servers <<< "$value"
    if (( ${#servers[@]} == 0 )); then
        [[ "$allow_empty" == "yes" ]] && return 0
        echo "❌ $name must contain at least one IP address" >&2
        return 1
    fi
    for server in "${servers[@]}"; do
        if ! [[ "$server" =~ ^[0-9A-Fa-f:.]+$ ]] \
            || [[ "$server" != *.* && "$server" != *:* ]]; then
            echo "❌ $name contains an invalid IP address: $server" >&2
            return 1
        fi
    done
}

validate_dns_list DNS_SERVERS "$DNS_SERVERS" no
validate_dns_list DNS_FALLBACK_SERVERS "$DNS_FALLBACK_SERVERS" yes

# Underscored override is an isolated regression-test seam, not user config.
DROPIN_DIR="${_FPI_RESOLVED_DROPIN_DIR:-/etc/systemd/resolved.conf.d}"
DROPIN_FILE="$DROPIN_DIR/fpi-dns.conf"

DESIRED_CONFIG="[Resolve]
DNS=$DNS_SERVERS
FallbackDNS=$DNS_FALLBACK_SERVERS"

sudo mkdir -p "$DROPIN_DIR"

if [ -f "$DROPIN_FILE" ] && printf '%s\n' "$DESIRED_CONFIG" | sudo cmp -s - "$DROPIN_FILE"; then
    echo "✅ DNS config already up to date ($DROPIN_FILE)"
else
    echo "🔧 Writing $DROPIN_FILE (DNS=$DNS_SERVERS, FallbackDNS=$DNS_FALLBACK_SERVERS)..."
    printf '%s\n' "$DESIRED_CONFIG" | sudo tee "$DROPIN_FILE" >/dev/null
    if command -v restorecon &>/dev/null; then
        sudo restorecon "$DROPIN_FILE"
    fi

    echo "🔄 Restarting systemd-resolved..."
    sudo systemctl restart systemd-resolved
    echo "✅ DNS resolvers configured"
fi

echo ""
resolvectl status 2>/dev/null | grep -A2 "Current DNS Server\|DNS Servers" | sed 's/^/   /' || true
