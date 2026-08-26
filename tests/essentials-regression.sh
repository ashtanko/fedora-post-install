#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() {
    local haystack="$1" needle="$2"
    [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}
assert_file_contains() {
    local file="$1" needle="$2"
    grep -Fq -- "$needle" "$file" || fail "expected $file to contain: $needle"
}

test_automatic_updates_dnf5() {
    local root="$TEST_ROOT/automatic" fakebin="$TEST_ROOT/automatic/bin"
    local config="$TEST_ROOT/automatic/automatic.conf" calls="$TEST_ROOT/automatic/calls"
    mkdir -p "$root/home" "$root/systemd" "$fakebin"
    : > "$calls"

    cat > "$fakebin/dnf" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "--version" ]]; then
    echo "${DNF_MOCK_VERSION:-dnf5 version 5.2.12}"
    exit 0
fi
exit 99
EOF
    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
echo "rpm $*" >> "$ESSENTIALS_CALLS"
exit 0
EOF
    cat > "$fakebin/systemctl" <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$ESSENTIALS_CALLS"
[[ "${1:-}" == "is-enabled" ]] && exit 1
exit 0
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    cat > "$fakebin/restorecon" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$fakebin"/*

    HOME="$root/home" PATH="$fakebin:$PATH" ESSENTIALS_CALLS="$calls" \
        _FPI_DNF_AUTOMATIC_CONFIG_FILE="$config" _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" \
        ENABLE_AUTO_UPDATES=yes /bin/bash "$REPO_ROOT/essentials/auto-updates.sh" >/dev/null

    assert_file_contains "$calls" "rpm -q --quiet dnf5-plugin-automatic"
    assert_file_contains "$calls" "systemctl enable --now dnf5-automatic.timer"
    assert_file_contains "$config" "upgrade_type = security"
    assert_file_contains "$config" "apply_updates = yes"
    assert_file_contains "$config" "reboot = never"

    : > "$calls"
    HOME="$root/home" PATH="$fakebin:$PATH" ESSENTIALS_CALLS="$calls" \
        DNF_MOCK_VERSION="4.22.0" _FPI_DNF_AUTOMATIC_CONFIG_FILE="$root/automatic-dnf4.conf" \
        _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" ENABLE_AUTO_UPDATES=yes \
        /bin/bash "$REPO_ROOT/essentials/auto-updates.sh" >/dev/null
    assert_file_contains "$calls" "rpm -q --quiet dnf-automatic"
    assert_file_contains "$calls" "systemctl enable --now dnf-automatic.timer"
    pass "automatic updates select the correct DNF5 and DNF4 packages and timers"
}

test_firewalld_preserves_zone_and_allows_ssh() {
    local root="$TEST_ROOT/firewall" fakebin="$TEST_ROOT/firewall/bin"
    local calls="$TEST_ROOT/firewall/calls"
    local ssh_rule_line start_line
    mkdir -p "$root/home" "$root/systemd" "$fakebin"
    : > "$calls"

    cat > "$fakebin/dnf" <<'EOF'
#!/bin/bash
exit 99
EOF
    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
echo "rpm $*" >> "$ESSENTIALS_CALLS"
exit 0
EOF
    cat > "$fakebin/systemctl" <<'EOF'
#!/bin/bash
echo "systemctl $*" >> "$ESSENTIALS_CALLS"
[[ "${1:-}" == "is-active" ]] && exit 1
exit 0
EOF
    cat > "$fakebin/firewall-cmd" <<'EOF'
#!/bin/bash
echo "firewall-cmd $*" >> "$ESSENTIALS_CALLS"
case " $* " in
    *" --query-service=ssh "*) exit 1 ;;
    *" --list-all "*) echo "public (active)"; exit 0 ;;
esac
exit 0
EOF
    cat > "$fakebin/firewall-offline-cmd" <<'EOF'
#!/bin/bash
echo "firewall-offline-cmd $*" >> "$ESSENTIALS_CALLS"
case " $* " in
    *" --get-default-zone "*) echo public; exit 0 ;;
    *" --get-zones "*) echo "FedoraServer FedoraWorkstation public"; exit 0 ;;
    *" --query-service=ssh "*) exit 1 ;;
esac
exit 0
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    chmod +x "$fakebin"/*

    HOME="$root/home" PATH="$fakebin:$PATH" ESSENTIALS_CALLS="$calls" \
        _FPI_SYSTEMD_RUNTIME_DIR="$root/systemd" ENABLE_FIREWALL=yes \
        /bin/bash "$REPO_ROOT/essentials/firewall.sh" >/dev/null

    assert_file_contains "$calls" "rpm -q --quiet firewalld"
    assert_file_contains "$calls" "systemctl enable --now firewalld"
    assert_file_contains "$calls" "firewall-offline-cmd --zone=public --add-service=ssh"
    assert_file_contains "$calls" "firewall-cmd --zone=public --add-service=ssh"
    if grep -Fq -- "--set-default-zone" "$calls"; then
        fail "firewall script unexpectedly replaced the existing default zone"
    fi
    ssh_rule_line=$(grep -nF "firewall-offline-cmd --zone=public --add-service=ssh" "$calls" | cut -d: -f1)
    start_line=$(grep -nF "systemctl enable --now firewalld" "$calls" | cut -d: -f1)
    [[ "$ssh_rule_line" -lt "$start_line" ]] || fail "firewalld started before its SSH rule was persisted"
    pass "firewalld persists SSH before activation and keeps the selected zone"
}

test_swap_is_opt_in_and_btrfs_safe() {
    local root="$TEST_ROOT/swap" fakebin="$TEST_ROOT/swap/bin"
    local swapfile="$TEST_ROOT/swap/swapfile" fstab="$TEST_ROOT/swap/fstab"
    local calls="$TEST_ROOT/swap/calls" output
    mkdir -p "$root/home" "$fakebin"
    : > "$calls"
    : > "$fstab"

    cat > "$fakebin/swapon" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "--show" ]]; then
    exit 0
fi
echo "swapon $*" >> "$ESSENTIALS_CALLS"
EOF
    cat > "$fakebin/findmnt" <<'EOF'
#!/bin/bash
echo btrfs
EOF
    cat > "$fakebin/btrfs" <<'EOF'
#!/bin/bash
echo "btrfs $*" >> "$ESSENTIALS_CALLS"
touch "${@: -1}"
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
    cat > "$fakebin/restorecon" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$fakebin"/*

    output=$(HOME="$root/home" PATH="$fakebin:$PATH" ESSENTIALS_CALLS="$calls" \
        SWAP_FILE="$swapfile" FSTAB_FILE="$fstab" ENABLE_DISK_SWAP=no \
        /bin/bash "$REPO_ROOT/essentials/swap.sh")
    assert_contains "$output" "disk swap is opt-in on Fedora"
    [[ ! -e "$swapfile" ]] || fail "default swap policy unexpectedly created a disk file"

    HOME="$root/home" PATH="$fakebin:$PATH" ESSENTIALS_CALLS="$calls" \
        SWAP_FILE="$swapfile" FSTAB_FILE="$fstab" SWAP_SIZE_GB=4 ENABLE_DISK_SWAP=yes \
        /bin/bash "$REPO_ROOT/essentials/swap.sh" >/dev/null
    assert_file_contains "$calls" "btrfs filesystem mkswapfile --size 4G $swapfile"
    assert_file_contains "$calls" "swapon $swapfile"
    assert_file_contains "$fstab" "$swapfile none swap sw 0 0"
    pass "disk swap defaults off and uses Btrfs-native creation when enabled"
}

test_fedora_essentials_contract() {
    local legacy_pattern='\bapt(-get)?\b|\bdpkg\b|\.deb\b|ppa:|/etc/apt|unattended-upgrades|\bufw\b|/etc/default/locale|locale-gen'
    if rg -ni "$legacy_pattern" "$REPO_ROOT/essentials"; then
        fail "essentials still contain a Debian/Ubuntu package or service mechanism"
    fi
    [[ ! -e "$REPO_ROOT/essentials/motd-news.sh" ]] || fail "Ubuntu-only motd-news script still exists"
    if rg -n 'motd-news|ENABLE_UFW' \
        "$REPO_ROOT/config/catalog.txt" "$REPO_ROOT/tests/manifest.sh" \
        "$REPO_ROOT/updates/skipped.txt" "$REPO_ROOT/docs/SCRIPTS.md" \
        "$REPO_ROOT/docs/CONFIG.md" "$REPO_ROOT/docs/SECURITY.md"; then
        fail "removed Ubuntu-only essentials remain in a synchronized inventory"
    fi

    assert_file_contains "$REPO_ROOT/essentials/fail2ban.sh" "dnf_install fail2ban fail2ban-firewalld"
    assert_file_contains "$REPO_ROOT/essentials/fail2ban.sh" "backend  = systemd"
    # These are literal source contracts; the dollar-prefixed names must not expand here.
    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/essentials/locale-timezone.sh" 'dnf_install "glibc-langpack-$LOCALE_LANGUAGE"'
    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/essentials/journald.sh" 'sudo restorecon "$DROPIN_FILE"'
    # shellcheck disable=SC2016
    assert_file_contains "$REPO_ROOT/essentials/sysctl-limits.sh" 'sudo restorecon "$SYSCTL_FILE"'
    pass "essentials have Fedora-native contracts and synchronized inventories"
}

test_automatic_updates_dnf5
test_firewalld_preserves_zone_and_allows_ssh
test_swap_is_opt_in_and_btrfs_safe
test_fedora_essentials_contract

echo "✅ essentials regression checks passed"
