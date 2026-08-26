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

echo "🚀 Installing Ollama..."

SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"

if command -v ollama &>/dev/null; then
    echo "✅ Ollama already installed ($(ollama --version 2>/dev/null | head -1))"
    echo "💡 To upgrade, rerun this script"
else
    # The official installer publishes x86_64 and aarch64 Linux builds. Reject
    # unsupported hosts before installing prerequisites or running it.
    rpm_arch >/dev/null
    dnf_install curl zstd

    echo "📦 Downloading and running official Ollama installer..."
    OLLAMA_INSTALLER=$(mktemp)
    trap 'rm -f "$OLLAMA_INSTALLER"' EXIT
    curl -fsSL --retry 3 --retry-all-errors -o "$OLLAMA_INSTALLER" https://ollama.com/install.sh
    sh "$OLLAMA_INSTALLER"
    rm -f "$OLLAMA_INSTALLER"
    trap - EXIT

    if ! command -v ollama &>/dev/null; then
        echo "❌ Installation failed or 'ollama' is not in PATH"
        exit 1
    fi

    echo ""
    echo "✅ Ollama installed successfully!"
    echo "   $(ollama --version 2>/dev/null | head -1)"
fi

if command -v restorecon &>/dev/null; then
    OLLAMA_BIN="$(command -v ollama)"
    case "$OLLAMA_BIN" in
        /usr/*) sudo restorecon "$OLLAMA_BIN" ;;
    esac
    for OLLAMA_UNIT in /etc/systemd/system/ollama.service /usr/lib/systemd/system/ollama.service; do
        if [ -e "$OLLAMA_UNIT" ]; then
            sudo restorecon "$OLLAMA_UNIT"
        fi
    done
fi

# Ensure the systemd service is up (the installer sets it up on systemd hosts)
if [ -d "$SYSTEMD_RUNTIME_DIR" ] && command -v systemctl &>/dev/null \
    && systemctl cat ollama.service &>/dev/null; then
    if systemctl is-active --quiet ollama.service; then
        echo "✅ ollama.service is running"
    else
        echo "📦 Starting ollama.service..."
        sudo systemctl enable --now ollama.service
    fi
else
    echo "⚠️  systemd is not running or ollama.service is unavailable; start 'ollama serve' manually"
fi

echo ""
echo "💡 Pull a model to get started, e.g.:"
echo "     ollama pull llama3.2"
echo "     ollama run llama3.2"
echo "💡 API is exposed on http://localhost:11434"
