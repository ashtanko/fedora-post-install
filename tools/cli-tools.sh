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

echo "🚀 Installing CLI developer tools..."

# Fedora packages expose the intended command names directly: `bat`, `fd`,
# `eza`, and `gh`. No compatibility links or third-party repositories are
# needed, so DNF remains the sole owner of this package set.
dnf_install bat fzf ripgrep eza jq htop tmux tree gh

for COMMAND in bat fzf rg eza jq htop tmux tree gh; do
    if ! command -v "$COMMAND" &>/dev/null; then
        echo "❌ $COMMAND installation failed or is not in PATH"
        exit 1
    fi
done

echo ""
echo "✅ CLI tools installation complete!"
echo "   bat    - better cat with syntax highlighting"
echo "   fzf    - fuzzy finder"
echo "   rg     - ripgrep (fast grep)"
echo "   eza    - modern ls"
echo "   jq     - JSON processor"
echo "   htop   - interactive process viewer"
echo "   tmux   - terminal multiplexer"
echo "   tree   - directory tree viewer"
echo "   gh     - GitHub CLI"
