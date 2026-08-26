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

echo "🚀 Installing Postman..."

INSTALL_DIR="${POSTMAN_INSTALL_DIR:-$HOME/.local/share/Postman}"
BIN_LINK="$HOME/.local/bin/postman"
DESKTOP_FILE="$HOME/.local/share/applications/postman.desktop"
POSTMAN_BIN="$INSTALL_DIR/Postman"

if [ -x "$POSTMAN_BIN" ]; then
    echo "✅ Postman already installed at $INSTALL_DIR"
    echo "💡 Postman self-updates; remove $INSTALL_DIR to force reinstall."
    exit 0
fi

if [ -e "$INSTALL_DIR" ] || [ -L "$INSTALL_DIR" ]; then
    echo "❌ Refusing to replace incomplete existing path: $INSTALL_DIR" >&2
    echo "   Move or remove it, then re-run this installer." >&2
    exit 1
fi

case "$(rpm_arch)" in
    x86_64)  ARCH="linux_64" ;;
    aarch64) ARCH="linux_arm64" ;;
esac

echo "📦 Ensuring curl + tar are present..."
dnf_install curl tar

echo "🔍 Downloading Postman ($ARCH)..."
INSTALL_PARENT="$(dirname "$INSTALL_DIR")"
mkdir -p "$INSTALL_PARENT"
TMP=$(mktemp -d "$INSTALL_PARENT/.postman-stage.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
curl -fL --progress-bar --retry 3 --retry-all-errors -o "$TMP/postman.tar.gz" \
    "https://dl.pstmn.io/download/latest/$ARCH"

tar -tzf "$TMP/postman.tar.gz" > "$TMP/archive.list"
while IFS= read -r MEMBER; do
    case "$MEMBER" in
        Postman|Postman/*) ;;
        *)
            echo "❌ Postman archive contains an unexpected path: $MEMBER" >&2
            exit 1
            ;;
    esac
    case "/$MEMBER/" in
        */../*|*/./*)
            echo "❌ Postman archive contains an unsafe path: $MEMBER" >&2
            exit 1
            ;;
    esac
done < "$TMP/archive.list"

tar -xzf "$TMP/postman.tar.gz" -C "$TMP"

if [ ! -x "$TMP/Postman/Postman" ]; then
    echo "❌ Postman binary missing after extract"
    exit 1
fi

mv "$TMP/Postman" "$INSTALL_DIR"

mkdir -p "$(dirname "$BIN_LINK")"
ln -sf "$POSTMAN_BIN" "$BIN_LINK"

# shellcheck disable=SC2016
PATH_LINE='[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac'
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$RC" ] || continue
    # shellcheck disable=SC2016
    grep -qF '$HOME/.local/bin' "$RC" || echo "$PATH_LINE" >> "$RC"
done

mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Postman
Exec=$POSTMAN_BIN
Icon=$INSTALL_DIR/app/icons/icon_128x128.png
Categories=Development;
Terminal=false
StartupWMClass=Postman
EOF

echo ""
echo "✅ Postman installed at $INSTALL_DIR"
echo "💡 Launch from the application menu, or run: postman"
