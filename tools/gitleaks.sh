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
echo "🚀 Installing gitleaks (secret scanner)..."

# tools/pre-commit-setup.sh wires gitleaks in as a pre-commit hook, but only
# for repos that adopt that config. This installs the binary so any repo can
# be scanned ad hoc — including ones cloned before the hook existed.
if command -v gitleaks &>/dev/null; then
    echo "✅ gitleaks already installed ($(gitleaks version 2>/dev/null | head -1))"
    exit 0
fi

echo "📦 Installing gitleaks from Fedora..."
dnf_install gitleaks

if ! command -v gitleaks &>/dev/null; then
    echo "❌ gitleaks installation failed or is not in PATH"
    exit 1
fi

echo ""
echo "✅ gitleaks installed ($(gitleaks version 2>/dev/null | head -1))"
echo "💡 Scan a working tree:   gitleaks dir ."
echo "💡 Scan full git history: gitleaks git ."
echo "💡 Already wired as a pre-commit hook by tools/pre-commit-setup.sh"
