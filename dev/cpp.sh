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

echo "🚀 Installing C/C++ toolchain..."

# Fedora's development-tools group owns the compiler and core build toolchain.
# clang-tools-extra supplies clang-tidy; clang supplies clang-format.
dnf_group_install development-tools
dnf_install \
    clang cmake ninja-build pkgconf-pkg-config ccache \
    gdb lldb clang-tools-extra cppcheck valgrind

echo ""
echo "✅ C/C++ toolchain installed!"
echo "   gcc / clang    - compilers"
echo "   cmake / ninja  - build systems"
echo "   ccache         - compiler cache (speeds up rebuilds)"
echo "   gdb / lldb     - debuggers"
echo "   clang-format   - formatter"
echo "   clang-tidy     - linter"
echo "   cppcheck       - static analyzer"
echo "   valgrind       - memory error detector"
echo "💡 Enable ccache for a project: cmake -DCMAKE_CXX_COMPILER_LAUNCHER=ccache ..."
