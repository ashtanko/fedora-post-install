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

echo "🚀 Installing Azure CLI..."

if dnf_installed azure-cli && command -v az &>/dev/null; then
    echo "✅ Azure CLI already installed ($(az version --output tsv 2>/dev/null | head -1))"
    exit 0
fi

dnf_install curl gnupg2
echo "📦 Adding Microsoft's signed Azure CLI repository..."
repo_add azure-cli \
    'https://packages.microsoft.com/rhel/9/prod/' \
    'https://packages.microsoft.com/keys/microsoft.asc' \
    'BC528686B50D79E339D3721CEB3E94ADBE1229CF'
dnf_install azure-cli

if ! command -v az &>/dev/null; then
    echo "❌ Azure CLI installation failed or 'az' is not in PATH"
    exit 1
fi

echo ""
echo "✅ Azure CLI installed ($(az version --output tsv 2>/dev/null | head -1))"
echo "💡 Authenticate:  az login"
echo "💡 Set a subscription: az account set --subscription <name-or-id>"
echo "💡 kubectl for AKS:    az aks get-credentials --resource-group <rg> --name <cluster>"
