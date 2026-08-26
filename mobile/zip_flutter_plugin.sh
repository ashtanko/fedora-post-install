#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
# shellcheck source=lib/config.bash
source "$CONFIG_HELPER" || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
# shellcheck source=lib/pkg.bash
source "$PKG_HELPER" || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
load_config "$REPO_ROOT"

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <path_to_flutter_plugin> [output_filename.zip]" >&2
    exit 1
fi

CALLER_DIR="$(pwd -P)"
if ! PLUGIN_PATH="$(realpath -- "$1" 2>/dev/null)" || [ ! -d "$PLUGIN_PATH" ]; then
    echo "❌ Flutter plugin directory not found: $1" >&2
    exit 1
fi

OUTPUT_ZIP="${2:-plugin_distribution.zip}"
case "$OUTPUT_ZIP" in
    /*) OUTPUT_PATH="$(realpath -m -- "$OUTPUT_ZIP")" ;;
    *) OUTPUT_PATH="$(realpath -m -- "$CALLER_DIR/$OUTPUT_ZIP")" ;;
esac
if [ -d "$OUTPUT_PATH" ]; then
    echo "❌ Archive output is a directory: $OUTPUT_PATH" >&2
    exit 1
fi
declare -a OUTPUT_EXCLUDES=()
case "$OUTPUT_PATH" in
    "$PLUGIN_PATH"/*)
        OUTPUT_RELATIVE="${OUTPUT_PATH#"$PLUGIN_PATH"/}"
        OUTPUT_EXCLUDES+=("$OUTPUT_RELATIVE")
        ;;
esac

echo "🚀 Packaging Flutter plugin..."
dnf_install zip

OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
mkdir -p "$OUTPUT_DIR"
TMP="$(mktemp -d "$OUTPUT_DIR/.flutter-plugin-archive.XXXXXX")"
TMP_ARCHIVE="$TMP/archive.zip"
trap 'rm -rf "$TMP"' EXIT
case "$TMP" in
    "$PLUGIN_PATH"/*)
        TMP_RELATIVE="${TMP#"$PLUGIN_PATH"/}"
        OUTPUT_EXCLUDES+=("$TMP_RELATIVE" "$TMP_RELATIVE/*")
        ;;
esac

cd -- "$PLUGIN_PATH"
echo "📦 Archiving Flutter plugin from: $PLUGIN_PATH"

# Always build a fresh archive so files removed since a previous run cannot
# survive as stale ZIP entries. The destination is replaced only after zip
# completes successfully.
zip -r "$TMP_ARCHIVE" . -x \
    "build/*" \
    "*/build/*" \
    ".dart_tool/*" \
    "*/.dart_tool/*" \
    ".git/*" \
    "*/.git/*" \
    ".idea/*" \
    "*/.idea/*" \
    ".vscode/*" \
    "*/.vscode/*" \
    "*.iml" \
    ".pub-cache/*" \
    "*/.pub-cache/*" \
    "pubspec.lock" \
    "*/pubspec.lock" \
    "android/.gradle/*" \
    "android/local.properties" \
    "ios/.symlinks/*" \
    "ios/Pods/*" \
    "ios/Podfile.lock" \
    "coverage/*" \
    "*/coverage/*" \
    ".flutter-plugins" \
    ".flutter-plugins-dependencies" \
    ".DS_Store" \
    "*/.DS_Store" \
    "${OUTPUT_EXCLUDES[@]}"

mv -f -- "$TMP_ARCHIVE" "$OUTPUT_PATH"
rmdir "$TMP"
trap - EXIT

echo "✅ Archive created at: $OUTPUT_PATH"
