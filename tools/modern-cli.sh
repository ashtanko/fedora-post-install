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

echo "🚀 Installing modern CLI productivity extras..."

ARCH=$(release_arch)
case "$ARCH" in
    amd64) LAZYGIT_ARCH="x86_64" ;;
    arm64) LAZYGIT_ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

BIN_DIR="/usr/local/bin"
# Fedora carries these tools in its own repositories and exposes the intended
# binaries (`delta`, `fd`, `zoxide`, `dust`, and `tldr`) without compatibility
# symlinks. lazygit remains a verified upstream release because Fedora does not
# currently package it.
dnf_install btop direnv hyperfine git-delta fd-find zoxide du-dust tealdeer \
    curl tar

# --- lazygit (GitHub release) ---
if command -v lazygit &>/dev/null; then
    echo "✅ lazygit already installed"
else
    echo "🔍 Resolving latest lazygit release..."
    LG_VERSION=$(latest_github_tag jesseduffield/lazygit)
    LG_NUM=${LG_VERSION#v}
    LG_ASSET="lazygit_${LG_NUM}_linux_${LAZYGIT_ARCH}.tar.gz"
    LG_URL="https://github.com/jesseduffield/lazygit/releases/download/${LG_VERSION}/${LG_ASSET}"
    echo "📦 Downloading lazygit $LG_VERSION..."
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors \
        -o "$TMP/lazygit.tar.gz" "$LG_URL"

    echo "🔒 Verifying checksum..."
    LG_CHECKSUMS="$TMP/checksums.txt"
    curl -fsSL --retry 3 --retry-all-errors -o "$LG_CHECKSUMS" \
        "https://github.com/jesseduffield/lazygit/releases/download/${LG_VERSION}/checksums.txt"
    EXPECTED_SHA=$(awk -v want="$LG_ASSET" '$2 == want {print $1; exit}' "$LG_CHECKSUMS")
    [[ "$EXPECTED_SHA" =~ ^[0-9a-fA-F]{64}$ ]] \
        || { echo "❌ lazygit checksum manifest is missing a valid digest for $LG_ASSET"; exit 1; }
    echo "$EXPECTED_SHA  $TMP/lazygit.tar.gz" | sha256sum --check --quiet
    echo "✅ Checksum verified"

    tar -xzf "$TMP/lazygit.tar.gz" -C "$TMP"
    sudo install -m 0755 "$TMP/lazygit" "$BIN_DIR/lazygit"
    echo "✅ lazygit installed → $BIN_DIR/lazygit"
fi

# --- Shell integration for direnv + zoxide (idempotent rc-file edits) ---
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$RC" ] || continue
    SHELL_NAME=$(basename "$RC" | sed -E 's/^\.//;s/rc$//')   # zsh | bash

    if ! grep -q 'direnv hook' "$RC"; then
        {
            echo ""
            echo "# direnv"
            echo "eval \"\$(direnv hook $SHELL_NAME)\""
        } >> "$RC"
        echo "✅ Added direnv hook to $RC"
    fi

    if ! grep -q 'zoxide init' "$RC"; then
        {
            echo ""
            echo "# zoxide"
            echo "eval \"\$(zoxide init $SHELL_NAME)\""
        } >> "$RC"
        echo "✅ Added zoxide init to $RC"
    fi
done

echo ""
echo "✅ Modern CLI extras installed!"
echo "   lazygit   - terminal UI for git"
echo "   delta     - syntax-highlighting pager for diffs"
echo "   zoxide    - smarter cd (z <partial-dir-name>)"
echo "   btop      - resource monitor"
echo "   direnv    - per-directory env vars"
echo "   fd        - friendlier find"
echo "   dust      - disk usage with bars"
echo "   hyperfine - command-line benchmarking"
echo "   tldr      - simplified man pages"
echo "💡 Reload your shell to activate direnv + zoxide hooks"
