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

ANDROID_STUDIO_BIN="$HOME/.local/share/android-studio/bin/studio.sh"
if [ ! -x "$ANDROID_STUDIO_BIN" ]; then
    echo "⏭️  Skipping Android Studio update: the project-managed tarball installation was not found."
    exit 0
fi

echo "🚀 Checking for an Android Studio update..."
FPI_ANDROID_STUDIO_UPDATE=1 /bin/bash "$REPO_ROOT/ide/android-studio.sh"
