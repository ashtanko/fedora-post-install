# shellcheck shell=bash

_node_version_at_least() {
    local current="${1#v}" required="${2#v}"

    [[ "$current" =~ ^[0-9]+([.][0-9]+){1,2}([+-].*)?$ ]] || return 1
    [[ "$(printf '%s\n' "$required" "$current" | sort -V | head -1)" == "$required" ]]
}

# Select an existing compatible Node.js/npm pair, or install Node.js 22 from
# NodeSource's signed RPM repository. The caller must source lib/pkg.bash first.
# On success NODE_BIN and NPM_BIN contain the exact executables to use.
ensure_node_runtime() {
    local required_version="${1:?ensure_node_runtime requires a minimum version}"
    local current_version="" repo_arch

    NODE_BIN=""
    NPM_BIN=""

    if command -v node &>/dev/null; then
        current_version="$(node --version 2>/dev/null || true)"
        if _node_version_at_least "$current_version" "$required_version"; then
            NODE_BIN="$(command -v node)"
            if command -v npm &>/dev/null; then
                NPM_BIN="$(command -v npm)"
                return 0
            fi

            echo "📦 Installing npm for the existing compatible Node.js runtime..."
            dnf_install npm
            if command -v npm &>/dev/null; then
                NPM_BIN="$(command -v npm)"
                return 0
            fi
        fi
    fi

    # NodeSource publishes Node.js 22 for these two RPM architectures. Reject
    # anything else before installing prerequisites or changing repositories.
    repo_arch="$(rpm_arch)" || return 1

    echo "📦 Installing Node.js 22 via the signed NodeSource RPM repository..."
    dnf_install curl gnupg2
    # NodeSource does not publish repomd.xml signatures. Package signatures
    # remain mandatory and the current RPM signing key is fingerprint-pinned.
    repo_add nodesource-node22 \
        "https://rpm.nodesource.com/pub_22.x/nodistro/nodejs/$repo_arch" \
        'https://rpm.nodesource.com/gpgkey/ns-operations-public.key' \
        '242B813831AF09562B6C46F76B88DA4E3AF28A14' \
        0
    sudo dnf -q install -y --refresh --setopt=install_weak_deps=False nodejs

    NODE_BIN="/usr/bin/node"
    NPM_BIN="/usr/bin/npm"
    if [ ! -x "$NODE_BIN" ] || [ ! -x "$NPM_BIN" ]; then
        echo "❌ NodeSource did not install both /usr/bin/node and /usr/bin/npm" >&2
        return 1
    fi

    current_version="$("$NODE_BIN" --version 2>/dev/null || true)"
    if ! _node_version_at_least "$current_version" "$required_version"; then
        echo "❌ Node.js $required_version+ is required, found ${current_version:-unknown}" >&2
        return 1
    fi
}
