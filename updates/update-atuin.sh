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

ATUIN_BIN="$HOME/.local/bin/atuin"
if [ ! -x "$ATUIN_BIN" ]; then
    echo "⏭️  Skipping Atuin update: the user-local installation was not found."
    exit 0
fi
if [ -L "$ATUIN_BIN" ] || [ ! -f "$ATUIN_BIN" ] || [ ! -O "$ATUIN_BIN" ]; then
    echo "⏭️  Skipping Atuin update: $ATUIN_BIN is not a user-owned standalone binary."
    exit 0
fi

BEFORE_VERSION=$("$ATUIN_BIN" --version 2>/dev/null | head -1 || true)
echo "🚀 Updating Atuin..."
echo "   Before: ${BEFORE_VERSION:-version unknown}"

FPI_ATUIN_UPDATE=1 /bin/bash "$REPO_ROOT/tools/atuin.sh"

if [ ! -x "$ATUIN_BIN" ]; then
    echo "❌ Atuin was not found at $ATUIN_BIN after the update" >&2
    exit 1
fi

AFTER_VERSION=$("$ATUIN_BIN" --version 2>/dev/null | head -1 || true)
echo "✅ Atuin update complete"
echo "   After:  ${AFTER_VERSION:-version unknown}"
