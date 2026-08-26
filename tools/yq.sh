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
echo "🚀 Installing yq (YAML/JSON/XML processor)..."

# tools/cli-tools.sh installs jq for JSON; yq is the YAML counterpart, which
# this toolchain leans on constantly (Kubernetes manifests, pre-commit configs,
# GitHub Actions workflows, docker-compose files).
if command -v yq &>/dev/null; then
    echo "✅ yq already installed ($(yq --version 2>/dev/null | head -1))"
    exit 0
fi

echo "📦 Installing yq from Fedora..."
dnf_install yq

if ! command -v yq &>/dev/null; then
    echo "❌ yq installation failed or is not in PATH"
    exit 1
fi

echo ""
echo "✅ yq installed ($(yq --version 2>/dev/null | head -1))"
echo "💡 Read a value:   yq '.services.web.image' docker-compose.yml"
echo "💡 YAML → JSON:    yq -o=json '.' config.yml"
echo "💡 Edit in place:  yq -i '.version = \"2\"' config.yml"
