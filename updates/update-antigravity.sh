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

if ! rpm -q --quiet antigravity; then
    echo "⏭️  Antigravity is not installed from the RPM package this project configures; skipping update."
    exit 0
fi

# Read versions from RPM rather than launching the Electron GUI, which needs a
# display and may create user state during a maintenance-only operation.
BEFORE_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' antigravity 2>/dev/null || true)
echo "🚀 Updating Antigravity..."
echo "   Before: ${BEFORE_VERSION:-version unknown}"

sudo dnf -q upgrade -y --refresh antigravity

AFTER_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' antigravity 2>/dev/null || true)
echo "✅ Antigravity update complete"
echo "   After:  ${AFTER_VERSION:-version unknown}"
