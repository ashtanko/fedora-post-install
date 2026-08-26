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

test_base_uses_dnf_and_development_tools() {
    local root="$TEST_ROOT/base" fakebin="$TEST_ROOT/base/bin" calls="$TEST_ROOT/base/calls"
    mkdir -p "$root/home" "$fakebin"
    : > "$calls"

    cat > "$fakebin/dnf" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "--version" ]]; then
    echo "dnf5 version 5.2.12"
    exit 0
fi
echo "dnf $*" >> "$SYSTEM_CALLS"
EOF
    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
echo "rpm $*" >> "$SYSTEM_CALLS"
exit 0
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    cat > "$fakebin/git" <<'EOF'
#!/bin/bash
echo "git $*" >> "$SYSTEM_CALLS"
[[ "${1:-}" == "--version" ]] && echo "git version test"
exit 0
EOF
    cat > "$fakebin/tool-version" <<'EOF'
#!/bin/bash
echo "$(basename "$0") test version"
EOF
    cat > "$fakebin/gsettings" <<'EOF'
#!/bin/bash
exit 1
EOF
    for tool in gcc make curl wget; do
        ln -s tool-version "$fakebin/$tool"
    done
    chmod +x "$fakebin"/*

    HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" SYSTEM_CALLS="$calls" \
        GIT_NAME="CI Tester" GIT_EMAIL="ci@example.com" GIT_DEFAULT_BRANCH=main GIT_EDITOR=nano \
        /bin/bash "$REPO_ROOT/system/base.sh" >/dev/null

    assert_file_contains "$calls" "dnf -q upgrade -y --refresh"
    assert_file_contains "$calls" "dnf -q group install -y --setopt=install_weak_deps=False development-tools"
    for package in gnome-tweaks git curl wget ca-certificates; do
        assert_file_contains "$calls" "rpm -q --quiet $package"
    done
    assert_file_contains "$calls" "git config --global user.email ci@example.com"
    pass "base setup refreshes DNF and installs Fedora development tools"
}

test_chrony_package_and_service() {
    local root="$TEST_ROOT/chrony" fakebin="$TEST_ROOT/chrony/bin" calls="$TEST_ROOT/chrony/calls"
    mkdir -p "$root/home" "$root/systemd" "$fakebin"
    : > "$calls"

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
echo "rpm $*" >> "$SYSTEM_CALLS"
exit 0
EOF
    cat > "$fakebin/dnf" <<'EOF'
#!/bin/bash
exit 99
EOF
    cat > "$fakebin/systemctl" <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$SYSTEM_CALLS"
[[ "${1:-}" == "is-enabled" ]] && exit 1
exit 0
EOF
    cat > "$fakebin/chronyc" <<'EOF'
#!/bin/bash
echo "Reference ID: test"
EOF
    cat > "$fakebin/chronyd" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    chmod +x "$fakebin"/*

    HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" SYSTEM_CALLS="$calls" \
        _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" /bin/bash "$REPO_ROOT/system/ntp.sh" >/dev/null

    assert_file_contains "$calls" "rpm -q --quiet chrony"
    assert_file_contains "$calls" "systemctl enable --now chronyd"
    pass "time synchronization uses Fedora's chrony package and service"
}

test_resolved_configuration_is_safe_and_idempotent() {
    local root="$TEST_ROOT/dns" fakebin="$TEST_ROOT/dns/bin" calls="$TEST_ROOT/dns/calls"
    local dropin_dir="$TEST_ROOT/dns/resolved.conf.d" config="$TEST_ROOT/dns/resolved.conf.d/fpi-dns.conf"
    local status restart_count
    mkdir -p "$root/home" "$root/systemd" "$fakebin"
    : > "$calls"

    cat > "$fakebin/systemctl" <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$SYSTEM_CALLS"
[[ "${1:-}" == "is-active" ]] && exit 0
exit 0
EOF
    cat > "$fakebin/resolvectl" <<'EOF'
#!/bin/bash
echo "DNS Servers: 1.1.1.1"
EOF
    cat > "$fakebin/restorecon" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    chmod +x "$fakebin"/*

    for _ in 1 2; do
        HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" SYSTEM_CALLS="$calls" \
            _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" _FPI_RESOLVED_DROPIN_DIR="$dropin_dir" \
            DNS_SERVERS="1.1.1.1 9.9.9.9" DNS_FALLBACK_SERVERS="1.0.0.1" \
            /bin/bash "$REPO_ROOT/system/hosts-dns.sh" >/dev/null
    done

    assert_file_contains "$config" "DNS=1.1.1.1 9.9.9.9"
    restart_count=$(grep -cF "systemctl restart systemd-resolved" "$calls")
    [[ "$restart_count" -eq 1 ]] || fail "systemd-resolved restarted $restart_count times"
    if grep -Fq "systemctl enable systemd-resolved" "$calls"; then
        fail "DNS script enabled a resolver stack that Fedora did not already use"
    fi

    set +e
    HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" SYSTEM_CALLS="$calls" \
        _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" _FPI_RESOLVED_DROPIN_DIR="$dropin_dir" \
        DNS_SERVERS=$'1.1.1.1\nmalicious-setting=yes' \
        /bin/bash "$REPO_ROOT/system/hosts-dns.sh" >/dev/null 2>&1
    status=$?
    set -e
    [[ "$status" -ne 0 ]] || fail "multiline DNS configuration should be rejected"
    pass "DNS changes only an active resolved stack and rejects config injection"
}

test_keyd_config_and_selinux_labeling() {
    local root="$TEST_ROOT/keyd" fakebin="$TEST_ROOT/keyd/bin" calls="$TEST_ROOT/keyd/calls"
    local config_dir="$TEST_ROOT/keyd/etc-keyd" uinput="$TEST_ROOT/keyd/uinput" restart_count
    mkdir -p "$root/home" "$root/systemd" "$fakebin"
    : > "$calls"
    : > "$uinput"

    cat > "$fakebin/keyd" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$fakebin/systemctl" <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$SYSTEM_CALLS"
exit 0
EOF
    cat > "$fakebin/restorecon" <<'EOF'
#!/bin/bash
echo "restorecon $*" >> "$SYSTEM_CALLS"
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    chmod +x "$fakebin"/*

    for _ in 1 2; do
        HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" SYSTEM_CALLS="$calls" \
            _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" _FPI_KEYD_CONFIG_DIR="$config_dir" \
            _FPI_UINPUT_DEVICE="$uinput" /bin/bash "$REPO_ROOT/system/keyboard.sh" >/dev/null
    done

    assert_file_contains "$config_dir/default.conf" "leftalt = leftcontrol"
    assert_file_contains "$config_dir/default.conf" "leftcontrol = leftmeta"
    assert_file_contains "$calls" "restorecon -R $config_dir"
    restart_count=$(grep -cF "systemctl restart keyd" "$calls")
    [[ "$restart_count" -eq 1 ]] || fail "keyd restarted $restart_count times"
    pass "keyd configuration is idempotent and restores SELinux labels"
}

test_fedora_groups_and_static_contracts() {
    local root="$TEST_ROOT/groups" fakebin="$TEST_ROOT/groups/bin" calls="$TEST_ROOT/groups/calls"
    local effective
    mkdir -p "$root/home" "$fakebin"
    : > "$calls"

    cat > "$fakebin/id" <<'EOF'
#!/bin/bash
case "${1:-}" in
    -un) echo tester ;;
    -nG) echo wheel ;;
    *) exit 2 ;;
esac
EOF
    cat > "$fakebin/getent" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$fakebin/usermod" <<'EOF'
#!/bin/bash
echo "usermod $*" >> "$SYSTEM_CALLS"
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    chmod +x "$fakebin"/*

    HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" SYSTEM_CALLS="$calls" SUDO_USER='' \
        /bin/bash "$REPO_ROOT/system/user-groups.sh" >/dev/null
    for group in docker dialout wireshark; do
        assert_file_contains "$calls" "usermod -aG $group tester"
    done
    if grep -Fq plugdev "$calls"; then
        fail "Fedora default group handling still used plugdev"
    fi

    effective=$(grep -hEv '^[[:space:]]*(#|$)' "$REPO_ROOT"/system/*.sh)
    if rg -ni '\bapt(-get)?\b|\bdpkg\b|/etc/apt|locale-gen|systemd-timesyncd' <<< "$effective"; then
        fail "system scripts still execute a Debian/Ubuntu mechanism"
    fi
    if grep -Ev '^[[:space:]]*#' "$REPO_ROOT/system/hostname.sh" | grep -q '/etc/hosts'; then
        fail "hostname script still mutates /etc/hosts"
    fi
    if grep -q 'dash-to-dock' "$REPO_ROOT/system/base.sh"; then
        fail "base setup still configures Ubuntu's Dash to Dock extension"
    fi
    assert_file_contains "$REPO_ROOT/system/keyboard.sh" "copr_enable alternateved/keyd"
    assert_file_contains "$REPO_ROOT/system/gpg.sh" "dnf_install gnupg2"
    assert_file_contains "$REPO_ROOT/system/ssh.sh" "dnf_install openssh-clients"
    # Literal source contract: the dollar-prefixed name must not expand here.
    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/system/sudoers.sh" 'sudo restorecon "$DROPIN_FILE"'
    pass "system scripts use Fedora groups, packages, and configuration contracts"
}

test_base_uses_dnf_and_development_tools
test_chrony_package_and_service
test_resolved_configuration_is_safe_and_idempotent
test_keyd_config_and_selinux_labeling
test_fedora_groups_and_static_contracts

echo "✅ system regression checks passed"
