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

echo "🚀 Installing network diagnostic tools..."

# Rounds out the diagnostics story tools/wireshark.sh starts (packet capture)
# and system/hosts-dns.sh implies (resolver configuration worth verifying).
# Fedora package mappings: bind-utils owns dig, iproute owns ss, and
# nmap-ncat owns nc.
dnf_install mtr traceroute nmap bind-utils iproute lsof nmap-ncat iperf3 httpie whois

for COMMAND in mtr traceroute nmap dig ss lsof nc iperf3 http whois; do
    if ! command -v "$COMMAND" &>/dev/null; then
        echo "❌ $COMMAND installation failed or is not in PATH"
        exit 1
    fi
done

echo ""
echo "✅ Network tools installed!"
echo "   mtr        - continuous traceroute + loss stats"
echo "   nmap       - port/host scanner"
echo "   dig        - DNS lookups (verify system/hosts-dns.sh with: dig +short example.com)"
echo "   ss         - socket/listening-port inspection (ss -tulpn)"
echo "   lsof       - which process holds which file/port"
echo "   nc         - raw TCP/UDP connections"
echo "   iperf3     - bandwidth benchmarking between two hosts"
echo "   http       - HTTPie, human-friendly HTTP client"
echo "   whois      - domain/IP registration lookups"
echo "💡 Only scan hosts and networks you own or are authorised to test."
