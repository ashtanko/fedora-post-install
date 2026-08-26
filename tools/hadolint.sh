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
echo "🚀 Installing hadolint (Dockerfile linter)..."

if command -v hadolint &>/dev/null; then
    echo "✅ hadolint already installed ($(hadolint --version 2>/dev/null | head -1))"
    exit 0
fi

echo "📦 Installing hadolint from Fedora..."
dnf_install hadolint

if ! command -v hadolint &>/dev/null; then
    echo "❌ hadolint installation failed or is not in PATH"
    exit 1
fi

echo ""
echo "✅ hadolint installed ($(hadolint --version 2>/dev/null | head -1))"
echo "💡 Lint a Dockerfile: hadolint Dockerfile"
echo "💡 Ignore a rule inline: # hadolint ignore=DL3008"
echo "💡 Project-wide config lives in .hadolint.yaml"
echo "💡 tools/pre-commit-setup.sh can run this on every commit"
