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

echo "🚀 Installing Starship cross-shell prompt..."

USER_BIN="$HOME/.local/bin"
mkdir -p "$USER_BIN"
export PATH="$USER_BIN:$PATH"

if command -v starship &>/dev/null; then
    echo "✅ Starship already installed ($(starship --version | head -1))"
else
    dnf_install curl tar coreutils

    STARSHIP_ARCH=$(rpm_arch)
    case "$STARSHIP_ARCH" in
        x86_64|aarch64) ;;
        *) echo "❌ Unsupported Starship architecture: $STARSHIP_ARCH"; exit 1 ;;
    esac

    echo "🔍 Resolving latest Starship release..."
    STARSHIP_VERSION=$(latest_github_tag starship/starship)
    STARSHIP_ASSET="starship-${STARSHIP_ARCH}-unknown-linux-musl.tar.gz"
    STARSHIP_BASE="https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}"
    STARSHIP_TMP=$(mktemp -d)
    STARSHIP_STAGE=""
    cleanup() {
        rm -rf "$STARSHIP_TMP"
        if [ -n "$STARSHIP_STAGE" ]; then
            rm -f "$STARSHIP_STAGE"
        fi
    }
    trap cleanup EXIT

    echo "📦 Downloading Starship $STARSHIP_VERSION..."
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors \
        -o "$STARSHIP_TMP/$STARSHIP_ASSET" "$STARSHIP_BASE/$STARSHIP_ASSET"
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors \
        -o "$STARSHIP_TMP/$STARSHIP_ASSET.sha256" \
        "$STARSHIP_BASE/$STARSHIP_ASSET.sha256"

    echo "🔒 Verifying checksum..."
    EXPECTED_SHA=$(awk 'NR == 1 {print $1}' "$STARSHIP_TMP/$STARSHIP_ASSET.sha256")
    [[ "$EXPECTED_SHA" =~ ^[0-9a-fA-F]{64}$ ]] \
        || { echo "❌ Starship checksum file does not contain a valid SHA-256 digest"; exit 1; }
    echo "$EXPECTED_SHA  $STARSHIP_TMP/$STARSHIP_ASSET" | sha256sum --check --quiet
    tar -xzf "$STARSHIP_TMP/$STARSHIP_ASSET" -C "$STARSHIP_TMP" starship
    [ -f "$STARSHIP_TMP/starship" ] \
        || { echo "❌ starship was not found in the downloaded archive"; exit 1; }

    STARSHIP_STAGE=$(mktemp "$USER_BIN/.starship-stage.XXXXXX")
    install -m 0755 "$STARSHIP_TMP/starship" "$STARSHIP_STAGE"
    "$STARSHIP_STAGE" --version >/dev/null 2>&1 \
        || { echo "❌ Staged Starship binary failed validation"; exit 1; }
    mv -f "$STARSHIP_STAGE" "$USER_BIN/starship"
    STARSHIP_STAGE=""
    rm -rf "$STARSHIP_TMP"
    trap - EXIT
    echo "✅ Starship installed ($(starship --version | head -1))"
fi

configure_posix_shell() {
    local rc_file="$1"
    local shell_name="$2"
    local marker="# Starship prompt (added by starship.sh)"

    touch "$rc_file"
    if grep -q "starship init $shell_name" "$rc_file"; then
        echo "✅ Starship already configured for $shell_name"
        return
    fi

    {
        echo ""
        echo "$marker"
        # Keep these expansions literal so they run when the shell starts.
        # shellcheck disable=SC2016
        echo '[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac'
        echo "command -v starship >/dev/null 2>&1 && eval \"\$(starship init $shell_name)\""
    } >> "$rc_file"
    echo "✅ Configured Starship for $shell_name in $rc_file"
}

configure_fish() {
    local config_file="$HOME/.config/fish/config.fish"
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    if grep -q 'starship init fish' "$config_file"; then
        echo "✅ Starship already configured for fish"
        return
    fi

    {
        echo ""
        echo "# Starship prompt (added by starship.sh)"
        # Fish expands HOME when it loads the generated config.
        # shellcheck disable=SC2016
        echo 'fish_add_path "$HOME/.local/bin"'
        echo 'type -q starship; and starship init fish | source'
    } >> "$config_file"
    echo "✅ Configured Starship for fish in $config_file"
}

# Bash is present on every supported Fedora install. Configure optional shells
# only when installed or already used by the current account.
configure_posix_shell "$HOME/.bashrc" bash
if command -v zsh &>/dev/null || [ -f "$HOME/.zshrc" ]; then
    configure_posix_shell "$HOME/.zshrc" zsh
fi
if command -v fish &>/dev/null || [ -f "$HOME/.config/fish/config.fish" ]; then
    configure_fish
fi

echo "✅ Starship setup complete!"
echo "💡 Open a new terminal to activate the prompt"
