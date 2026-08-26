#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
[[ -r "$CONFIG_HELPER" ]] || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
# shellcheck source=../lib/config.bash
source "$CONFIG_HELPER"
load_config "$REPO_ROOT"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
[[ -r "$PKG_HELPER" ]] || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
# shellcheck source=../lib/pkg.bash
source "$PKG_HELPER"

echo "🚀 Preparing prerequisites for VMware Workstation..."

ARCH="$(rpm_arch)"
if [[ "$ARCH" != x86_64 ]]; then
    echo "❌ VMware Workstation for Linux supports x86_64 hosts only (detected $ARCH)" >&2
    exit 1
fi

KERNEL_RELEASE="$(uname -r)"
VMWARE_PREREQUISITES=(
    "kernel-devel-$KERNEL_RELEASE"
    kernel-headers
    gcc
    gcc-c++
    make
    perl
    git
    elfutils-libelf-devel
    openssl
    mokutil
)

prerequisites_ready=true
for package in "${VMWARE_PREREQUISITES[@]}"; do
    if ! dnf_installed "$package"; then
        prerequisites_ready=false
        break
    fi
done

if [[ "$prerequisites_ready" == true ]]; then
    echo "✅ VMware kernel-build prerequisites are already installed for $KERNEL_RELEASE"
else
    echo "📦 Installing Fedora kernel headers and build tools..."
    if ! dnf_install "${VMWARE_PREREQUISITES[@]}"; then
        echo "❌ Could not install kernel-devel for the running kernel: $KERNEL_RELEASE" >&2
        echo "💡 Apply Fedora updates, reboot into the latest kernel, and rerun this script" >&2
        exit 1
    fi
fi

SECURE_BOOT_NOTE=""
if mokutil --sb-state 2>/dev/null | grep -Fqi 'SecureBoot enabled'; then
    SECURE_BOOT_NOTE=$(cat <<'EOF'

⚠️ Secure Boot is enabled. VMware's vmmon and vmnet modules must be signed
   before they can load. After installing the bundle and building the modules,
   follow Broadcom KB 315309 using Fedora's signing helper at:
     /usr/src/kernels/$(uname -r)/scripts/sign-file
   Sign both modules, import the generated DER certificate with mokutil, then
   reboot and complete "Enroll MOK" in the firmware dialog.
EOF
)
fi

cat <<EOF

✅ Prerequisites installed.

Manual next steps:
  1. Sign in at https://support.broadcom.com/ and download the current
     VMware Workstation Pro for Linux .bundle (free for all use since 17.5.2).
  2. Run:    chmod +x VMware-Workstation-Full-*.bundle
             sudo ./VMware-Workstation-Full-*.bundle
  3. Build or refresh the host modules:
             sudo vmware-modconfig --console --install-all
$SECURE_BOOT_NOTE

💡 After each Fedora kernel upgrade, rerun this script for matching kernel-devel,
   then rerun vmware-modconfig. Secure Boot systems must sign rebuilt modules.
EOF
