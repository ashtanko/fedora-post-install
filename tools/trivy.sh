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

echo "🚀 Installing Trivy (container + filesystem vulnerability scanner)..."

if command -v trivy &>/dev/null; then
    echo "✅ Trivy already installed ($(trivy --version 2>/dev/null | head -1))"
    exit 0
fi

echo "📦 Adding Aqua Security's Trivy RPM repository..."
dnf_install ca-certificates curl gnupg2

# Aqua signs every RPM with this key, but its repository does not publish a
# repomd.xml.asc file. Keep package signature checking enabled while disabling
# only repository-metadata signature checking for this upstream repository.
# shellcheck disable=SC2016
repo_add trivy \
    'https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/' \
    'https://aquasecurity.github.io/trivy-repo/rpm/public.key' \
    '825AD9036F7C850E6A6FED4935B8ACA44FD9CA9F' \
    0
dnf_install trivy

if ! command -v trivy &>/dev/null; then
    echo "❌ Trivy installation failed or is not in PATH"
    exit 1
fi

echo ""
echo "✅ Trivy installed ($(trivy --version 2>/dev/null | head -1))"
echo "💡 Scan a container image:      trivy image <image>"
echo "💡 Scan this working tree:      trivy fs ."
echo "💡 Scan IaC (Terraform, k8s):   trivy config ."
echo "💡 Fail only on real problems:  trivy image --severity HIGH,CRITICAL --exit-code 1 <image>"
echo "💡 First run downloads the vulnerability DB (~several hundred MB)"
