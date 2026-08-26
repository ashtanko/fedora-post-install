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

if ! CODE_BIN=$(command -v code); then
    echo "⏭️  Visual Studio Code is not installed; skipping update."
    exit 0
fi

if ! rpm -q --quiet code; then
    echo "⏭️  Visual Studio Code is not managed by the Microsoft RPM package installed by this project; skipping update."
    exit 0
fi

if [ "$(rpm -qf --queryformat '%{NAME}\n' "$CODE_BIN" 2>/dev/null || true)" != "code" ]; then
    echo "⏭️  The active code executable is not owned by the code RPM package; skipping update."
    exit 0
fi

BEFORE_VERSION=$("$CODE_BIN" --version 2>/dev/null | head -1 || true)
echo "🚀 Updating Visual Studio Code..."
echo "   Before: ${BEFORE_VERSION:-version unknown}"

sudo dnf -q upgrade -y --refresh code

AFTER_VERSION=$("$CODE_BIN" --version 2>/dev/null | head -1 || true)
echo "✅ Visual Studio Code update complete"
echo "   After:  ${AFTER_VERSION:-version unknown}"
