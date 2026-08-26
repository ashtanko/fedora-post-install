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

echo "🚀 Installing JetBrains Toolbox..."

INSTALL_DIR="${JETBRAINS_TOOLBOX_DIR:-$HOME/.local/share/JetBrains/Toolbox}"
TOOLBOX_BIN="$INSTALL_DIR/bin/jetbrains-toolbox"
DESKTOP_FILE="$HOME/.local/share/applications/jetbrains-toolbox.desktop"

if [ -x "$TOOLBOX_BIN" ]; then
    echo "✅ JetBrains Toolbox is already installed at $INSTALL_DIR"
    echo "💡 Toolbox manages its own updates."
    exit 0
fi
if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
    echo "❌ Refusing to replace $INSTALL_DIR because it is not a valid Toolbox installation"
    exit 1
fi

ARCH=$(rpm_arch)
case "$ARCH" in
    x86_64) DOWNLOAD_KEY=linux ;;
    aarch64) DOWNLOAD_KEY=linuxARM64 ;;
esac

# These are Fedora's runtime equivalents for JetBrains' documented Linux
# Toolbox requirements. Toolbox 2.7+ is no longer an AppImage, so FUSE is not
# needed for the current archive.
dnf_install curl python3 tar libXi libXrender libXtst glx-utils \
    fontconfig gtk3 dbus-daemon xcb-util-keysyms

echo "🔍 Resolving the latest JetBrains Toolbox release..."
META_URL="https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
TMP=$(mktemp -d)
STAGE=""
cleanup() {
    rm -rf -- "$TMP"
    [ -z "$STAGE" ] || rm -rf -- "$STAGE"
}
trap cleanup EXIT

curl -fsSL --retry 3 --retry-all-errors -o "$TMP/releases.json" "$META_URL"
mapfile -t RELEASE < <(python3 - "$TMP/releases.json" "$DOWNLOAD_KEY" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as metadata:
    release = json.load(metadata)["TBA"][0]
download = release["downloads"][sys.argv[2]]
print(download["link"])
print(download["checksumLink"])
print(release["version"])
PY
)
if [ "${#RELEASE[@]}" -ne 3 ]; then
    echo "❌ Could not resolve the latest Toolbox release" >&2
    exit 1
fi
DOWNLOAD_URL="${RELEASE[0]}"
CHECKSUM_URL="${RELEASE[1]}"
TOOLBOX_VERSION="${RELEASE[2]}"
if [[ "$DOWNLOAD_URL" != https://download.jetbrains.com/toolbox/*.tar.gz ]] \
    || [ "$CHECKSUM_URL" != "$DOWNLOAD_URL.sha256" ]; then
    echo "❌ JetBrains metadata returned an unexpected Toolbox download location" >&2
    exit 1
fi

echo "📥 Downloading JetBrains Toolbox $TOOLBOX_VERSION..."
curl -fL --progress-bar --retry 3 --retry-all-errors \
    -o "$TMP/toolbox.tar.gz" "$DOWNLOAD_URL"
curl -fsSL --retry 3 --retry-all-errors -o "$TMP/toolbox.sha256" "$CHECKSUM_URL"
EXPECTED_SHA=$(awk 'NR == 1 { print $1 }' "$TMP/toolbox.sha256")
if ! [[ "$EXPECTED_SHA" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "❌ JetBrains published an invalid Toolbox checksum" >&2
    exit 1
fi
echo "$EXPECTED_SHA  $TMP/toolbox.tar.gz" | sha256sum --check --quiet
echo "✅ Checksum verified"

INSTALL_PARENT=$(dirname "$INSTALL_DIR")
mkdir -p "$INSTALL_PARENT"
STAGE=$(mktemp -d "$INSTALL_PARENT/.toolbox-stage.XXXXXX")
tar -xzf "$TMP/toolbox.tar.gz" -C "$STAGE" --strip-components=1
if [ ! -x "$STAGE/bin/jetbrains-toolbox" ]; then
    echo "❌ Downloaded archive does not contain the Toolbox executable"
    exit 1
fi
mv -- "$STAGE" "$INSTALL_DIR"
STAGE=""

mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=$TOOLBOX_BIN
Icon=$INSTALL_DIR/jetbrains-toolbox.svg
Categories=Development;IDE;
Terminal=false
EOF

echo ""
echo "✅ JetBrains Toolbox $TOOLBOX_VERSION installed."
echo "💡 Launch it from your application menu, sign in, then choose which IDEs to install."
