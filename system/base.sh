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

echo "🚀 Starting base system setup..."

echo "📦 Refreshing Fedora metadata and upgrading the system..."
sudo dnf -q upgrade -y --refresh

# Fedora's development-tools group is the equivalent of Debian's
# build-essential and includes the compiler/make toolchain used by later scripts.
echo "📦 Ensuring the development toolchain is installed..."
dnf_group_install development-tools

echo "📦 Ensuring core workstation tools are installed..."
dnf_install gnome-tweaks git curl wget ca-certificates

# Verify key tools
for tool in gcc make git curl wget; do
    if command -v "$tool" &>/dev/null; then
        echo "✅ $tool: $($tool --version 2>&1 | head -1)"
    else
        echo "❌ $tool not found after install"
        exit 1
    fi
done

# Configure git identity and defaults from .env
if [ -n "${GIT_NAME:-}" ]; then
    git config --global user.name "$GIT_NAME"
    echo "✅ git user.name = $GIT_NAME"
fi
if [ -n "${GIT_EMAIL:-}" ]; then
    git config --global user.email "$GIT_EMAIL"
    echo "✅ git user.email = $GIT_EMAIL"
fi
if [ -n "${GIT_DEFAULT_BRANCH:-}" ]; then
    git config --global init.defaultBranch "$GIT_DEFAULT_BRANCH"
    echo "✅ git init.defaultBranch = $GIT_DEFAULT_BRANCH"
fi
if [ -n "${GIT_EDITOR:-}" ]; then
    git config --global core.editor "$GIT_EDITOR"
    echo "✅ git core.editor = $GIT_EDITOR"
fi

echo "✅ Base system setup complete!"
