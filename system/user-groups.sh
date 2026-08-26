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

# When the whole script is invoked with sudo, modify the invoking account rather
# than root. Normal setup.sh runs still resolve directly through id(1).
if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER="$(id -un)"
fi

echo "🚀 Adding $CURRENT_USER to common developer groups..."

# Groups later scripts rely on (docker.sh, hardware/USB tooling, Wireshark, etc.).
# Centralizing this here means those scripts don't each duplicate group-add logic,
# and it works whether or not the owning package is installed yet.

# Note: deliberately not named GROUPS — that's a bash builtin array (the
# current user's group IDs); assigning to it is a no-op that returns exit
# status 1, which set -e would treat as a hard failure.
read -ra TARGET_GROUPS <<< "${EXTRA_USER_GROUPS:-wheel docker dialout wireshark}"

ADDED=()
for GROUP in "${TARGET_GROUPS[@]}"; do
    [ -n "$GROUP" ] || continue

    # Translate the Debian administrative group for existing user configs and
    # ignore plugdev, which Fedora does not use for device-access policy.
    if [[ "$GROUP" == "sudo" ]]; then
        GROUP="wheel"
    elif [[ "$GROUP" == "plugdev" ]]; then
        echo "⏭️  Group 'plugdev' is not used on Fedora — skipping"
        continue
    fi

    if ! [[ "$GROUP" =~ ^[A-Za-z_][A-Za-z0-9_.-]*\$?$ ]]; then
        echo "❌ Invalid group name: $GROUP" >&2
        exit 1
    fi

    if ! getent group "$GROUP" &>/dev/null; then
        echo "⏭️  Group '$GROUP' doesn't exist yet — skipping (created when its package is installed)"
        continue
    fi

    if id -nG "$CURRENT_USER" | tr ' ' '\n' | grep -qx "$GROUP"; then
        echo "✅ $CURRENT_USER already in '$GROUP'"
    else
        echo "🔧 Adding $CURRENT_USER to '$GROUP'..."
        sudo usermod -aG "$GROUP" "$CURRENT_USER"
        ADDED+=("$GROUP")
    fi
done

if [ ${#ADDED[@]} -gt 0 ]; then
    echo ""
    echo "✅ Added to: ${ADDED[*]}"
    echo "💡 Log out and back in (or run 'newgrp <group>') for the new group membership to take effect."
else
    echo "✅ No group changes needed"
fi
