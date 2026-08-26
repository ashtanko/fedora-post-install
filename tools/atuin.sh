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
GITHUB_HELPER="$REPO_ROOT/lib/github.bash"
# shellcheck source=lib/github.bash
source "$GITHUB_HELPER" || { echo "❌ Missing github helper: $GITHUB_HELPER" >&2; exit 1; }

echo "🚀 Installing Atuin (searchable, syncable shell history)..."

USER_BIN="$HOME/.local/bin"
mkdir -p "$USER_BIN"
export PATH="$USER_BIN:$PATH"

if command -v atuin &>/dev/null && [ "${FPI_ATUIN_UPDATE:-0}" != "1" ]; then
    echo "✅ Atuin already installed ($(atuin --version 2>/dev/null | head -1))"
else
    # Fedora materially lagged upstream's Bash integration fixes at migration
    # time, so install the current checksum-published upstream release.
    dnf_install curl tar coreutils

    ATUIN_ARCH=$(rpm_arch)
    case "$ATUIN_ARCH" in
        x86_64|aarch64) ;;
        *) echo "❌ Unsupported Atuin architecture: $ATUIN_ARCH"; exit 1 ;;
    esac

    echo "🔍 Resolving latest Atuin release..."
    ATUIN_VERSION=$(latest_github_tag atuinsh/atuin)
    ATUIN_NUM=${ATUIN_VERSION#v}
    ATUIN_ASSET="atuin-${ATUIN_ARCH}-unknown-linux-gnu.tar.gz"
    ATUIN_BASE="https://github.com/atuinsh/atuin/releases/download/${ATUIN_VERSION}"
    ATUIN_TMP=$(mktemp -d)
    ATUIN_STAGE=""
    cleanup() {
        rm -rf "$ATUIN_TMP"
        if [ -n "$ATUIN_STAGE" ]; then
            rm -f "$ATUIN_STAGE"
        fi
    }
    trap cleanup EXIT

    echo "📦 Downloading Atuin $ATUIN_VERSION..."
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors \
        -o "$ATUIN_TMP/$ATUIN_ASSET" "$ATUIN_BASE/$ATUIN_ASSET"
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors \
        -o "$ATUIN_TMP/$ATUIN_ASSET.sha256" "$ATUIN_BASE/$ATUIN_ASSET.sha256"

    echo "🔒 Verifying checksum..."
    EXPECTED_SHA=$(awk 'NR == 1 {print $1}' "$ATUIN_TMP/$ATUIN_ASSET.sha256")
    [[ "$EXPECTED_SHA" =~ ^[0-9a-fA-F]{64}$ ]] \
        || { echo "❌ Atuin checksum file does not contain a valid SHA-256 digest"; exit 1; }
    echo "$EXPECTED_SHA  $ATUIN_TMP/$ATUIN_ASSET" | sha256sum --check --quiet
    mapfile -t ATUIN_MEMBERS < <(
        tar -tzf "$ATUIN_TMP/$ATUIN_ASSET" \
            | awk -F/ '$NF == "atuin" { print }'
    )
    if (( ${#ATUIN_MEMBERS[@]} != 1 )); then
        echo "❌ Expected exactly one atuin binary in the downloaded archive"
        exit 1
    fi
    ATUIN_STAGE=$(mktemp "$USER_BIN/.atuin-stage.XXXXXX")
    tar -xOzf "$ATUIN_TMP/$ATUIN_ASSET" "${ATUIN_MEMBERS[0]}" > "$ATUIN_STAGE"
    chmod 0755 "$ATUIN_STAGE"
    STAGE_VERSION=$("$ATUIN_STAGE" --version 2>/dev/null | head -1) \
        || { echo "❌ Staged Atuin binary failed validation"; exit 1; }
    case "$STAGE_VERSION" in
        *"$ATUIN_NUM"*) ;;
        *) echo "❌ Staged Atuin binary did not report $ATUIN_VERSION"; exit 1 ;;
    esac
    mv -f "$ATUIN_STAGE" "$USER_BIN/atuin"
    ATUIN_STAGE=""
    rm -rf "$ATUIN_TMP"
    trap - EXIT
    echo "✅ Atuin installed ($STAGE_VERSION)"
fi

# --- Shell integration (idempotent rc edits, same shape as modern-cli.sh) ---
if [ -f "$HOME/.zshrc" ] && ! grep -q 'atuin init zsh' "$HOME/.zshrc"; then
    {
        echo ""
        echo "# Atuin"
        # shellcheck disable=SC2016
        echo '[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac'
        # shellcheck disable=SC2016
        echo 'eval "$(atuin init zsh)"'
    } >> "$HOME/.zshrc"
    echo "✅ Added Atuin init to ~/.zshrc"
fi

if [ -f "$HOME/.bashrc" ] && ! grep -q 'atuin init bash' "$HOME/.bashrc"; then
    {
        echo ""
        echo "# Atuin"
        # shellcheck disable=SC2016
        echo '[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac'
        # shellcheck disable=SC2016
        echo 'eval "$(atuin init bash)"'
    } >> "$HOME/.bashrc"
    echo "✅ Added Atuin init to ~/.bashrc"
fi

FISH_CONFIG="$HOME/.config/fish/config.fish"
if [ -f "$FISH_CONFIG" ] && ! grep -q 'atuin init fish' "$FISH_CONFIG"; then
    {
        echo ""
        echo "# Atuin"
        # shellcheck disable=SC2016
        echo 'fish_add_path "$HOME/.local/bin"'
        echo "atuin init fish | source"
    } >> "$FISH_CONFIG"
    echo "✅ Added Atuin init to $FISH_CONFIG"
fi

echo ""
echo "✅ Atuin ready!"
echo "💡 Reload your shell, then press ↑ or Ctrl-R for the new history search"
echo "💡 Import your existing history: atuin import auto"
echo "💡 History stays local by default. Optional end-to-end encrypted sync:"
echo "     atuin register -u <username> -e <email>   (then: atuin sync)"
