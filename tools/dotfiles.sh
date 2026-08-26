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

echo "🚀 Installing chezmoi (dotfiles manager)..."

if command -v chezmoi &>/dev/null; then
    echo "✅ chezmoi already installed ($(chezmoi --version | head -1))"
else
    echo "📦 Installing chezmoi from Fedora..."
    dnf_install chezmoi
    if ! command -v chezmoi &>/dev/null; then
        echo "❌ chezmoi installation failed or is not in PATH"
        exit 1
    fi
    echo "✅ chezmoi installed ($(chezmoi --version | head -1))"
fi

# Optional: point an existing source-of-truth repo at chezmoi. `chezmoi init`
# only clones into ~/.local/share/chezmoi — it never touches target files —
# so this is safe to run unattended. Deliberately NOT running `--apply` here:
# that overwrites files in $HOME, and doing that without the user reviewing
# `chezmoi diff` first is the kind of surprise this toolkit avoids.
if [ -n "${DOTFILES_REPO:-}" ]; then
    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
        echo "✅ chezmoi source directory already initialized"
    else
        echo "📥 Initializing chezmoi from $DOTFILES_REPO..."
        chezmoi init "$DOTFILES_REPO"
        echo "✅ Source directory ready: ~/.local/share/chezmoi"
    fi
fi

echo ""
echo "✅ chezmoi ready!"
if [ -z "${DOTFILES_REPO:-}" ]; then
    echo "💡 Start tracking a file:   chezmoi add ~/.zshrc"
    echo "💡 Or pull an existing repo: DOTFILES_REPO=<url> bash tools/dotfiles.sh"
else
    echo "💡 Review before applying: chezmoi diff"
    echo "💡 Apply when ready:       chezmoi apply"
fi
