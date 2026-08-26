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

echo "🚀 Installing Docker Engine and Docker Desktop..."

ARCH=$(rpm_arch)
USERNAME="${USER:-$(id -un)}"
SYSTEMD_RUNTIME_DIR="${_FPI_SYSTEMD_RUNTIME_DIR:-/run/systemd/system}"

# --- Docker Engine ---
if dnf_installed podman-docker; then
    echo "❌ podman-docker owns the Docker-compatible CLI and conflicts with Docker CE" >&2
    echo "💡 Remove only that compatibility package first: sudo dnf remove podman-docker" >&2
    echo "   The Podman engine itself can remain installed alongside Docker." >&2
    exit 1
fi

dnf_install curl gnupg2
echo "📦 Configuring Docker's signed Fedora repository..."
repo_add docker-ce \
    "https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable" \
    'https://download.docker.com/linux/fedora/gpg' \
    '060A61C51B558A7F742B77AAC52FEB6B621E9F35'

if dnf_installed docker-ce && command -v docker &>/dev/null; then
    echo "✅ Docker Engine already installed ($(docker --version))"
else
    echo "📦 Installing Docker Engine..."
    dnf_install \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin container-selinux

    echo "✅ Docker Engine installed ($(docker --version))"
fi

if [ -d "$SYSTEMD_RUNTIME_DIR" ]; then
    sudo systemctl enable --now docker >/dev/null
else
    echo "⚠️  systemd is not running; Docker was installed but its service was not started"
fi

# Add current user to docker group
if groups "$USERNAME" | grep -q docker; then
    echo "✅ User already in docker group"
else
    echo "👤 Adding $USERNAME to docker group..."
    sudo usermod -aG docker "$USERNAME"
    echo "⚠️  Log out and back in (or run: newgrp docker) for group membership to take effect"
fi

# --- Docker Desktop ---
if [[ "${INSTALL_DOCKER_DESKTOP:-yes}" == "no" ]]; then
    echo "⏭️  Skipping Docker Desktop (INSTALL_DOCKER_DESKTOP=no)"
elif dnf_installed docker-desktop; then
    echo "✅ Docker Desktop already installed"
elif [ "$ARCH" != x86_64 ]; then
    echo "⚠️  Docker Desktop does not publish a Fedora aarch64 RPM; skipping Desktop"
    echo "   Docker Engine remains installed and usable."
else
    echo "📦 Downloading Docker Desktop..."
    RPM=$(mktemp --suffix=.rpm)
    trap 'rm -f "$RPM"' EXIT

    curl --proto '=https' --tlsv1.2 -fL --retry 3 --retry-all-errors \
        -o "$RPM" \
        'https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64.rpm'

    echo "🛠️  Installing Docker Desktop..."
    sudo dnf -q install -y --setopt=install_weak_deps=False \
        --setopt=localpkg_gpgcheck=True "$RPM"
    echo "✅ Docker Desktop installed"
fi  # end INSTALL_DOCKER_DESKTOP

echo ""
echo "✅ Docker setup complete!"
echo "💡 Start Docker Desktop: systemctl --user start docker-desktop"
