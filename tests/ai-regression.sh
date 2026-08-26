#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

assert_file_contains() {
    local file="$1" needle="$2"
    grep -Fq -- "$needle" "$file" || fail "expected $file to contain: $needle"
}

assert_line_before() {
    local file="$1" first="$2" second="$3" first_line second_line
    first_line="$(grep -nF -- "$first" "$file" | head -1 | cut -d: -f1)"
    second_line="$(grep -nF -- "$second" "$file" | head -1 | cut -d: -f1)"
    [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] \
        || fail "expected '$first' before '$second' in $file"
}

test_fedora_ai_contracts() {
    local script effective

    for script in "$REPO_ROOT"/ai/*.sh \
        "$REPO_ROOT"/lib/node.bash \
        "$REPO_ROOT"/updates/update-{aider,antigravity,claude,cline,codex,cursor-agent,gemini,github-copilot,goose,huggingface-cli,llama-cpp,mcp-inspector,mistral-vibe,opencode,pipx-tools}.sh; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|python3-venv|build-essential|libcurl4-openssl-dev' \
            <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu package path"
        fi
    done

    for script in antigravity claude cline gemini huggingface-cli litellm \
        llama-cpp llm-cli mcp-inspector ollama prompt-runner; do
        # Match the literal helper variable used by each installer.
        # shellcheck disable=SC2016
        assert_file_contains "$REPO_ROOT/ai/$script.sh" 'source "$PKG_HELPER"'
    done
    for script in cline gemini mcp-inspector; do
        # shellcheck disable=SC2016
        assert_file_contains "$REPO_ROOT/ai/$script.sh" 'source "$NODE_HELPER"'
        assert_file_contains "$REPO_ROOT/ai/$script.sh" 'ensure_node_runtime '
    done

    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/ai/claude.sh" \
        'https://downloads.claude.ai/claude-code/rpm/$CLAUDE_CHANNEL'
    assert_file_contains "$REPO_ROOT/ai/claude.sh" \
        '31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE'
    assert_file_contains "$REPO_ROOT/ai/claude.sh" 'dnf_install claude-code'

    assert_file_contains "$REPO_ROOT/ai/antigravity.sh" \
        'https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm'
    assert_file_contains "$REPO_ROOT/ai/antigravity.sh" \
        'EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796'
    assert_file_contains "$REPO_ROOT/ai/antigravity.sh" 'dnf_install antigravity'
    assert_file_contains "$REPO_ROOT/ai/antigravity.sh" \
        'https://dl.google.com/linux/linux_signing_key.pub'
    grep -A5 -F 'repo_add antigravity-rpm' "$REPO_ROOT/ai/antigravity.sh" \
        | grep -Fxq '    0' \
        || fail "Antigravity repository did not retain its audited metadata-signature exception"

    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/lib/node.bash" \
        'https://rpm.nodesource.com/pub_22.x/nodistro/nodejs/$repo_arch'
    assert_file_contains "$REPO_ROOT/lib/node.bash" \
        '242B813831AF09562B6C46F76B88DA4E3AF28A14'
    assert_file_contains "$REPO_ROOT/lib/node.bash" \
        'sudo dnf -q install -y --refresh --setopt=install_weak_deps=False nodejs'
    grep -A5 -F 'repo_add nodesource-node22' "$REPO_ROOT/lib/node.bash" \
        | grep -Fxq '        0' \
        || fail "NodeSource repository did not retain its audited metadata-signature exception"

    assert_file_contains "$REPO_ROOT/ai/llama-cpp.sh" \
        'dnf_group_install development-tools'
    assert_file_contains "$REPO_ROOT/ai/llama-cpp.sh" \
        'dnf_install cmake git ccache pkgconf-pkg-config libcurl-devel'
    assert_file_contains "$REPO_ROOT/ai/litellm.sh" 'dnf_install python3 pipx'
    assert_file_contains "$REPO_ROOT/ai/llm-cli.sh" 'dnf_install python3 pipx'
    assert_file_contains "$REPO_ROOT/ai/prompt-runner.sh" 'dnf_install curl jq'

    assert_line_before "$REPO_ROOT/ai/ollama.sh" \
        'rpm_arch >/dev/null' 'dnf_install curl zstd'
    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/ai/ollama.sh" 'sudo restorecon "$OLLAMA_BIN"'
    assert_file_contains "$REPO_ROOT/ai/ollama.sh" \
        'sudo systemctl enable --now ollama.service'

    pass "AI installers and coupled updaters contain only Fedora-native package paths"
}

make_node_stubs() {
    local fakebin="$1" node_version="$2" arch="$3"
    mkdir -p "$fakebin"

    cat > "$fakebin/node" <<EOF
#!/bin/bash
echo '$node_version'
EOF
    cat > "$fakebin/npm" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$fakebin/rpm" <<EOF
#!/bin/bash
if [[ "\${1:-}" == --eval ]]; then
    echo '$arch'
    exit 0
fi
exit 1
EOF
    for command_name in curl dnf sudo; do
        cat > "$fakebin/$command_name" <<'EOF'
#!/bin/bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$AI_TEST_CALLS"
exit 99
EOF
    done
    chmod +x "$fakebin"/*
}

test_node_runtime_selection() {
    local compatible_bin="$TEST_ROOT/node-compatible/bin"
    local unsupported_bin="$TEST_ROOT/node-unsupported/bin"
    local calls="$TEST_ROOT/node-calls" output status
    : > "$calls"
    make_node_stubs "$compatible_bin" v22.19.0 x86_64

    AI_TEST_CALLS="$calls" PATH="$compatible_bin:/usr/bin:/bin" \
        /bin/bash -c '
            source "$1/lib/pkg.bash"
            source "$1/lib/node.bash"
            ensure_node_runtime 22.19.0
            [[ "$NODE_BIN" == "$2/node" && "$NPM_BIN" == "$2/npm" ]]
        ' _ "$REPO_ROOT" "$compatible_bin"
    [[ ! -s "$calls" ]] \
        || fail "a compatible Node.js/npm pair still mutated package or repository state"

    : > "$calls"
    make_node_stubs "$unsupported_bin" v16.20.0 ppc64le
    set +e
    output="$(AI_TEST_CALLS="$calls" PATH="$unsupported_bin:/usr/bin:/bin" \
        /bin/bash -c '
            source "$1/lib/pkg.bash"
            source "$1/lib/node.bash"
            ensure_node_runtime 18.0.0
        ' _ "$REPO_ROOT" 2>&1)"
    status=$?
    set -e
    [[ "$status" -ne 0 ]] || fail "Node helper accepted an unsupported RPM architecture"
    [[ "$output" == *"Unsupported RPM architecture: ppc64le"* ]] \
        || fail "Node helper did not explain its architecture rejection"
    [[ ! -s "$calls" ]] \
        || fail "Node helper mutated package or network state before rejecting ppc64le"

    pass "Node runtime selection reuses compatible installs and rejects unsupported hosts safely"
}

test_inventory_and_update_ownership() {
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'ai/antigravity.sh|partial||rpm -q antigravity && command -v antigravity >/dev/null'
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'ai/claude.sh|yes|CLAUDE_CHANNEL=stable|rpm -q claude-code && command -v claude && claude --version'
    assert_file_contains "$REPO_ROOT/updates/catalog.txt" \
        'update-antigravity.sh|ai/antigravity.sh|targeted RPM package upgrade'
    assert_file_contains "$REPO_ROOT/updates/catalog.txt" \
        'update-claude.sh|ai/claude.sh|targeted RPM package or npm global upgrade, whichever owns the executable'
    assert_file_contains "$REPO_ROOT/updates/update-antigravity.sh" \
        'sudo dnf -q upgrade -y --refresh antigravity'
    assert_file_contains "$REPO_ROOT/updates/update-claude.sh" \
        'sudo dnf -q upgrade -y --refresh claude-code'

    pass "AI manifest artifacts and updater ownership match the Fedora installers"
}

test_fedora_ai_contracts
test_node_runtime_selection
test_inventory_and_update_ownership

echo "✅ AI regression checks passed"
