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

echo "🚀 Installing Neovim..."

# Fedora 43 ships Neovim 0.11 and Fedora 44 ships 0.12, so the distribution
# package is current enough to prefer over an independently managed tarball.
# Unlink only the command created by this repository's former tarball installer;
# retain the old installation directory for manual recovery.
LEGACY_INSTALL_DIR="${NVIM_INSTALL_DIR:-$HOME/.local/share/nvim-stable}"
LEGACY_LINK="$HOME/.local/bin/nvim"
if [ -L "$LEGACY_LINK" ] \
    && [ "$(readlink -m "$LEGACY_LINK")" = "$(readlink -m "$LEGACY_INSTALL_DIR/bin/nvim")" ]; then
    unlink "$LEGACY_LINK"
    echo "🔧 Removed the legacy Neovim tarball command link"
fi

if dnf_installed neovim; then
    echo "✅ Neovim is already installed ($(rpm -q --qf '%{VERSION}\n' neovim))"
else
    echo "📦 Installing Fedora's Neovim package..."
    dnf_install neovim
fi

# Write a small starter only when the user has no existing Neovim config.
NVIM_CONFIG="$HOME/.config/nvim"
if [ ! -e "$NVIM_CONFIG/init.lua" ] && [ ! -e "$NVIM_CONFIG/init.vim" ]; then
    mkdir -p "$NVIM_CONFIG"
    cat > "$NVIM_CONFIG/init.lua" <<'LUA'
-- Minimal Neovim starter — extend or replace with your own config.
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.expandtab      = true
vim.opt.shiftwidth     = 4
vim.opt.tabstop        = 4
vim.opt.smartcase      = true
vim.opt.ignorecase     = true
vim.opt.termguicolors  = true
vim.opt.clipboard      = "unnamedplus"
vim.g.mapleader        = " "
LUA
    echo "📝 Wrote starter $NVIM_CONFIG/init.lua"
fi

if command -v nvim &>/dev/null; then
    echo "✅ Neovim installed ($(nvim --version | head -1))"
else
    echo "❌ Neovim installation failed"
    exit 1
fi
