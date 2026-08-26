#!/bin/bash
# shellcheck disable=SC2016
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

assert_log_line() {
    local needle="$1" file="$2"
    grep -Fqx -- "$needle" "$file" || fail "expected $file to contain line: $needle"
}

assert_line_before() {
    local file="$1" first="$2" second="$3" first_line second_line
    first_line="$(grep -nF -- "$first" "$file" | head -1 | cut -d: -f1)"
    second_line="$(grep -nF -- "$second" "$file" | head -1 | cut -d: -f1)"
    [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] \
        || fail "expected '$first' before '$second' in $file"
}

test_fedora_vpn_contracts() {
    local script effective

    for script in "$REPO_ROOT"/vpn/*.sh; do
        grep -Fq 'source "$PKG_HELPER"' "$script" \
            || fail "$(basename "$script") does not source lib/pkg.bash"
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|\bsnap\b|install\.sh' \
            <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu or remote-installer path"
        fi
    done

    assert_file_contains "$REPO_ROOT/vpn/nord.sh" \
        'https://repo.nordvpn.com/yum/nordvpn/centos/$ARCH'
    assert_file_contains "$REPO_ROOT/vpn/nord.sh" \
        'https://repo.nordvpn.com/gpg/nordvpn_public.asc'
    assert_file_contains "$REPO_ROOT/vpn/nord.sh" \
        'BC5480EFEC5C081CE5BCFBE26B219E535C964CA1'
    assert_file_contains "$REPO_ROOT/vpn/nord.sh" 'dnf_install nordvpn'
    assert_file_contains "$REPO_ROOT/vpn/nord.sh" \
        'sudo systemctl enable --now nordvpnd.socket nordvpnd.service'

    assert_file_contains "$REPO_ROOT/vpn/tailscale.sh" \
        'https://pkgs.tailscale.com/stable/fedora/\$basearch'
    assert_file_contains "$REPO_ROOT/vpn/tailscale.sh" \
        'https://pkgs.tailscale.com/stable/fedora/repo.gpg'
    assert_file_contains "$REPO_ROOT/vpn/tailscale.sh" \
        '2596A99EAAB33821893C0A79458CA832957F5868'
    assert_file_contains "$REPO_ROOT/vpn/tailscale.sh" 'dnf_install tailscale'
    assert_file_contains "$REPO_ROOT/vpn/tailscale.sh" \
        'sudo systemctl enable --now tailscaled.service'
    assert_file_contains "$REPO_ROOT/vpn/tailscale.sh" \
        'sudo tailscale up --auth-key="$TAILSCALE_AUTHKEY"'

    assert_line_before "$REPO_ROOT/vpn/nord.sh" \
        'ARCH="$(rpm_arch)"' 'dnf_install curl gnupg2'
    assert_line_before "$REPO_ROOT/vpn/tailscale.sh" \
        'rpm_arch >/dev/null' 'dnf_install curl gnupg2'

    pass "VPN installers use Fedora packages and pinned vendor RPM repositories"
}

make_runtime_stubs() {
    local fakebin="$1"
    mkdir -p "$fakebin"

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == --eval ]]; then
    printf '%s\n' "${VPN_TEST_ARCH:-x86_64}"
    exit 0
fi
if [[ "${1:-}" == -q ]]; then
    package="${*: -1}"
    case " ${VPN_TEST_INSTALLED:-} " in
        *" $package "*) exit 0 ;;
        *) exit 1 ;;
    esac
fi
exit 1
EOF

    cat > "$fakebin/curl" <<'EOF'
#!/bin/bash
output=""
url=""
while (( $# > 0 )); do
    case "$1" in
        -o) output="$2"; shift 2 ;;
        https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ -n "$output" && -n "$url" ]]
printf '%s\n' "$url" > "$output"
printf 'curl %s\n' "$url" >> "$VPN_TEST_CALLS"
EOF

    cat > "$fakebin/gpg" <<'EOF'
#!/bin/bash
printf 'pub:-:4096:1:0000000000000000:0:0::::::\n'
printf 'fpr:::::::::%s:\n' "$VPN_TEST_FINGERPRINT"
EOF

    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >> "$VPN_TEST_CALLS"
if [[ "${1:-}" == install ]]; then
    if [[ " $* " == *" -d "* ]]; then
        exit 0
    fi
    source_file="${*: -2:1}"
    target_file="${*: -1}"
    captured="$VPN_TEST_CAPTURE_ROOT$target_file"
    mkdir -p "$(dirname "$captured")"
    cp "$source_file" "$captured"
fi
exit 0
EOF

    cat > "$fakebin/systemctl" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == is-active ]]; then
    exit 1
fi
exit 0
EOF

    cat > "$fakebin/nordvpn" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == --version ]]; then
    echo 'NordVPN Version 4.test'
fi
EOF

    cat > "$fakebin/tailscale" <<'EOF'
#!/bin/bash
case "${1:-}" in
    version) echo '1.test' ;;
    ip) echo '100.64.0.1' ;;
esac
EOF

    cat > "$fakebin/getent" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == group && "${2:-}" == nordvpn ]]; then
    echo 'nordvpn:x:987:'
    exit 0
fi
exit 2
EOF

    cat > "$fakebin/groups" <<'EOF'
#!/bin/bash
echo "${1:-tester} : ${1:-tester}"
EOF

    cat > "$fakebin/dnf" <<'EOF'
#!/bin/bash
printf 'dnf %s\n' "$*" >> "$VPN_TEST_CALLS"
exit 99
EOF

    cat > "$fakebin/restorecon" <<'EOF'
#!/bin/bash
exit 0
EOF

    chmod +x "$fakebin"/*
}

test_runtime_repository_service_and_auth_paths() {
    local root="$TEST_ROOT/runtime" fakebin="$TEST_ROOT/runtime/bin"
    local calls="$TEST_ROOT/runtime/calls" capture="$TEST_ROOT/runtime/capture"
    local systemd_dir="$TEST_ROOT/runtime/systemd" output auth_key
    mkdir -p "$root/home" "$capture" "$systemd_dir"
    : > "$calls"
    make_runtime_stubs "$fakebin"

    HOME="$root/home" USER=tester PATH="$fakebin:/usr/bin:/bin" \
        FEDORA_POST_INSTALL_CONFIG="$root/missing.env" \
        _FPI_SYSTEMD_RUNTIME_DIR="$systemd_dir" \
        VPN_TEST_ARCH=x86_64 VPN_TEST_INSTALLED='curl gnupg2 nordvpn' \
        VPN_TEST_FINGERPRINT=BC5480EFEC5C081CE5BCFBE26B219E535C964CA1 \
        VPN_TEST_CALLS="$calls" VPN_TEST_CAPTURE_ROOT="$capture" \
        /bin/bash "$REPO_ROOT/vpn/nord.sh" >/dev/null

    assert_file_contains "$capture/etc/yum.repos.d/nordvpn.repo" \
        'baseurl=https://repo.nordvpn.com/yum/nordvpn/centos/x86_64'
    assert_file_contains "$capture/etc/yum.repos.d/nordvpn.repo" 'gpgcheck=1'
    assert_file_contains "$capture/etc/yum.repos.d/nordvpn.repo" 'repo_gpgcheck=1'
    assert_log_line 'sudo systemctl enable --now nordvpnd.socket nordvpnd.service' "$calls"
    assert_log_line 'sudo usermod -aG nordvpn tester' "$calls"

    : > "$calls"
    auth_key='tskey-auth-test-secret'
    output="$(HOME="$root/home" USER=tester PATH="$fakebin:/usr/bin:/bin" \
        FEDORA_POST_INSTALL_CONFIG="$root/missing.env" \
        _FPI_SYSTEMD_RUNTIME_DIR="$systemd_dir" \
        TAILSCALE_AUTHKEY="$auth_key" \
        VPN_TEST_ARCH=aarch64 VPN_TEST_INSTALLED='curl gnupg2 tailscale' \
        VPN_TEST_FINGERPRINT=2596A99EAAB33821893C0A79458CA832957F5868 \
        VPN_TEST_CALLS="$calls" VPN_TEST_CAPTURE_ROOT="$capture" \
        /bin/bash "$REPO_ROOT/vpn/tailscale.sh")"

    assert_file_contains "$capture/etc/yum.repos.d/tailscale-stable.repo" \
        'baseurl=https://pkgs.tailscale.com/stable/fedora/$basearch'
    assert_file_contains "$capture/etc/yum.repos.d/tailscale-stable.repo" 'gpgcheck=1'
    assert_file_contains "$capture/etc/yum.repos.d/tailscale-stable.repo" 'repo_gpgcheck=1'
    assert_log_line 'sudo systemctl enable --now tailscaled.service' "$calls"
    assert_log_line "sudo tailscale up --auth-key=$auth_key" "$calls"
    [[ "$output" != *"$auth_key"* ]] || fail "Tailscale auth key leaked into installer output"

    pass "VPN repository, systemd, group, and auth-key paths behave correctly with isolated stubs"
}

test_unsupported_architectures_fail_before_mutation() {
    local root="$TEST_ROOT/unsupported" fakebin="$TEST_ROOT/unsupported/bin"
    local calls="$TEST_ROOT/unsupported/calls" script output status
    mkdir -p "$root/home" "$root/capture"
    : > "$calls"
    make_runtime_stubs "$fakebin"

    for script in nord tailscale; do
        : > "$calls"
        set +e
        output="$(HOME="$root/home" USER=tester PATH="$fakebin:/usr/bin:/bin" \
            FEDORA_POST_INSTALL_CONFIG="$root/missing.env" \
            VPN_TEST_ARCH=ppc64le VPN_TEST_INSTALLED='curl gnupg2 nordvpn tailscale' \
            VPN_TEST_FINGERPRINT=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \
            VPN_TEST_CALLS="$calls" VPN_TEST_CAPTURE_ROOT="$root/capture" \
            /bin/bash "$REPO_ROOT/vpn/$script.sh" 2>&1)"
        status=$?
        set -e
        [[ "$status" -ne 0 ]] || fail "$script accepted an unsupported RPM architecture"
        [[ "$output" == *"Unsupported RPM architecture: ppc64le"* ]] \
            || fail "$script did not explain its architecture rejection"
        [[ ! -s "$calls" ]] \
            || fail "$script mutated package or repository state before rejecting ppc64le"
    done

    pass "VPN installers reject unsupported RPM architectures before mutation"
}

test_inventory_and_update_ownership() {
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'vpn/nord.sh|no|||needs systemd and a live VPN daemon; Fedora repository, service, and group paths are covered by vpn-regression.sh'
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'vpn/tailscale.sh|no|||needs systemd and tailnet enrollment; Fedora repository, service, and auth-key paths are covered by vpn-regression.sh'
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'vpn/nord.sh|vendor RPM package is maintained through its configured repository and DNF'
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'vpn/tailscale.sh|vendor RPM package is maintained through its configured repository and DNF'
    pass "VPN manifest and updater ownership stay synchronized"
}

test_fedora_vpn_contracts
test_runtime_repository_service_and_auth_paths
test_unsupported_architectures_fail_before_mutation
test_inventory_and_update_ownership

echo "✅ VPN regression checks passed"
