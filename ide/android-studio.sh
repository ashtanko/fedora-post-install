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

echo "🚀 Installing Android Studio..."

# Google publishes Android Studio for Linux x86_64 only. Reject unsupported
# hosts before installing prerequisites or changing the user's files.
ARCH=$(rpm_arch)
if [ "$ARCH" != "x86_64" ]; then
    echo "❌ Android Studio for Linux supports x86_64 only (detected: $ARCH)."
    exit 1
fi

INSTALL_DIR="$HOME/.local/share/android-studio"
MANAGED_BIN="$INSTALL_DIR/bin/studio.sh"
BIN_LINK="$HOME/.local/bin/android-studio"
DESKTOP_FILE="$HOME/.local/share/applications/android-studio.desktop"

ensure_launchers() {
    mkdir -p "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP_FILE")"
    ln -sfn "$MANAGED_BIN" "$BIN_LINK"
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Android Studio
Exec=$BIN_LINK %f
Icon=$INSTALL_DIR/bin/studio.svg
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-studio
EOF
}

if [ -x "$MANAGED_BIN" ] && [ "${FPI_ANDROID_STUDIO_UPDATE:-0}" != "1" ]; then
    ensure_launchers
    echo "✅ Android Studio is already installed at $INSTALL_DIR"
    echo "💡 Update with: bash updates/update-android-studio.sh"
    exit 0
fi
if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]] && [ ! -x "$MANAGED_BIN" ]; then
    echo "❌ Refusing to replace $INSTALL_DIR because it is not a valid Android Studio installation"
    exit 1
fi

dnf_install curl python3 tar

# The official download page publishes the current Linux archive URL and its
# SHA-256 in the same release table. Resolve both together so the installer and
# updater do not rely on a stale version-specific URL.
METADATA_URL="https://developer.android.com/studio"
TMP=$(mktemp -d)
STAGE=""
BACKUP=""
cleanup() {
    rm -rf -- "$TMP"
    [ -z "$STAGE" ] || rm -rf -- "$STAGE"
    if [ -n "$BACKUP" ] && [ -e "$BACKUP" ] && [ ! -e "$INSTALL_DIR" ]; then
        mv -- "$BACKUP" "$INSTALL_DIR" \
            || echo "⚠️  Previous Android Studio install retained at $BACKUP" >&2
    fi
}
trap cleanup EXIT

echo "🔍 Resolving the current Android Studio release..."
curl -fsSL --retry 3 --retry-all-errors -o "$TMP/studio.html" "$METADATA_URL"
mapfile -t RELEASE < <(python3 - "$TMP/studio.html" <<'PY'
import re
import sys
from html.parser import HTMLParser


class StudioPage(HTMLParser):
    def __init__(self):
        super().__init__()
        self.link = ""
        self.rows = []
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "a" and attributes.get("id") == "agree-button__studio_linux_bundle_download":
            self.link = attributes.get("href", "")
        elif tag == "tr":
            self.row = []
        elif tag == "td" and self.row is not None:
            self.cell = []

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag == "td" and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None


parser = StudioPage()
with open(sys.argv[1], encoding="utf-8") as page:
    parser.feed(page.read())

filename = parser.link.rsplit("/", 1)[-1]
checksum = ""
for row in parser.rows:
    if filename in row:
        checksum = next((cell.lower() for cell in row if re.fullmatch(r"[0-9a-fA-F]{64}", cell)), "")
        break

if not parser.link or not re.fullmatch(r"android-studio-[A-Za-z0-9._-]+-linux\.tar\.gz", filename):
    raise SystemExit("current Linux archive was not found on the Android Studio download page")
if not re.fullmatch(r"[0-9a-f]{64}", checksum):
    raise SystemExit("current Linux archive checksum was not found on the Android Studio download page")

print(parser.link)
print(filename)
print(checksum)
PY
)

if [ "${#RELEASE[@]}" -ne 3 ]; then
    echo "❌ Could not resolve a checksum-published Android Studio Linux release" >&2
    exit 1
fi
DOWNLOAD_URL="${RELEASE[0]}"
ARCHIVE_NAME="${RELEASE[1]}"
EXPECTED_SHA="${RELEASE[2]}"
if [[ "$DOWNLOAD_URL" != https://*"/android/studio/ide-zips/"*"/$ARCHIVE_NAME" ]]; then
    echo "❌ Android Studio download page returned an unexpected archive URL" >&2
    exit 1
fi

if [ "${FPI_ANDROID_STUDIO_UPDATE:-0}" = "1" ] \
    && [ -r "$INSTALL_DIR/.fpi-archive-sha256" ] \
    && [ "$(<"$INSTALL_DIR/.fpi-archive-sha256")" = "$EXPECTED_SHA" ]; then
    ensure_launchers
    echo "✅ Android Studio is already current"
    exit 0
fi

echo "📥 Downloading $ARCHIVE_NAME..."
curl -fL --progress-bar --retry 3 --retry-all-errors \
    -o "$TMP/android-studio.tar.gz" "$DOWNLOAD_URL"
echo "$EXPECTED_SHA  $TMP/android-studio.tar.gz" | sha256sum --check --quiet
echo "✅ Checksum verified"

INSTALL_PARENT=$(dirname "$INSTALL_DIR")
mkdir -p "$INSTALL_PARENT"
STAGE=$(mktemp -d "$INSTALL_PARENT/.android-studio-stage.XXXXXX")
tar -xzf "$TMP/android-studio.tar.gz" -C "$STAGE" --strip-components=1
if [ ! -x "$STAGE/bin/studio.sh" ] || [ ! -r "$STAGE/product-info.json" ]; then
    echo "❌ Downloaded archive is not a valid Android Studio installation"
    exit 1
fi
printf '%s\n' "$EXPECTED_SHA" > "$STAGE/.fpi-archive-sha256"
printf '%s\n' "$DOWNLOAD_URL" > "$STAGE/.fpi-source-url"

if [ -e "$INSTALL_DIR" ]; then
    BACKUP=$(mktemp -d "$INSTALL_PARENT/.android-studio-backup.XXXXXX")
    rmdir "$BACKUP"
    mv -- "$INSTALL_DIR" "$BACKUP"
fi
if ! mv -- "$STAGE" "$INSTALL_DIR"; then
    if [ -n "$BACKUP" ] && mv -- "$BACKUP" "$INSTALL_DIR"; then
        BACKUP=""
    fi
    echo "❌ Could not activate Android Studio"
    exit 1
fi
STAGE=""
if [ -n "$BACKUP" ]; then
    rm -rf -- "$BACKUP"
    BACKUP=""
fi

ensure_launchers

echo ""
echo "✅ Android Studio installed at $INSTALL_DIR"
echo "💡 Launch it from the application menu, or run: android-studio"
echo "💡 First run walks you through Android SDK and emulator setup."
echo "💡 Re-run 'flutter doctor' afterwards if dev/flutter.sh is already installed."
