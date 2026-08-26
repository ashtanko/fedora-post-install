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

assert_line_before() {
    local file="$1" first="$2" second="$3" first_line second_line
    first_line="$(grep -nF -- "$first" "$file" | head -1 | cut -d: -f1)"
    second_line="$(grep -nF -- "$second" "$file" | head -1 | cut -d: -f1)"
    [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] \
        || fail "expected '$first' before '$second' in $file"
}

test_fedora_software_contracts() {
    local script effective

    for script in "$REPO_ROOT"/software/*.sh; do
        grep -Fq 'source "$PKG_HELPER"' "$script" \
            || fail "$(basename "$script") does not source lib/pkg.bash"
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|\bsnap\b' \
            <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu package path"
        fi
    done

    assert_file_contains "$REPO_ROOT/software/boxes.sh" 'dnf_group_install virtualization'
    assert_file_contains "$REPO_ROOT/software/boxes.sh" 'dnf_install gnome-boxes'
    assert_file_contains "$REPO_ROOT/software/boxes.sh" \
        'sudo systemctl enable --now libvirtd.service'
    assert_file_contains "$REPO_ROOT/software/boxes.sh" \
        'sudo virsh --connect qemu:///system net-autostart default'

    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'https://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'E9A491A3DE247814E7E067EAE06F8ECDD651FF2E'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'dnf_install VirtualBox akmod-VirtualBox'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'sudo akmods --force --rebuild --kernels "$KERNEL_RELEASE"'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'mokutil --test-key "$AKMOD_CERT"'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'sudo mokutil --import $AKMOD_CERT'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        '"$EXTPACK_BASE_URL/SHA256SUMS"'
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        "sed -E 's/^([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/'"
    assert_file_contains "$REPO_ROOT/software/virtualbox.sh" \
        'sudo "$VBOXMANAGE" extpack install --replace "$TMP"'
    assert_line_before "$REPO_ROOT/software/virtualbox.sh" \
        'ARCH="$(rpm_arch)"' 'if ! dnf_install'
    assert_line_before "$REPO_ROOT/software/virtualbox.sh" \
        'sudo kmodgenca -a' 'dnf_install VirtualBox akmod-VirtualBox'
    assert_line_before "$REPO_ROOT/software/virtualbox.sh" \
        'mokutil --test-key "$AKMOD_CERT"' 'sudo modprobe vboxdrv'

    for package in kernel-devel kernel-headers gcc make perl elfutils-libelf-devel; do
        assert_file_contains "$REPO_ROOT/software/vmware.sh" "$package"
    done
    assert_file_contains "$REPO_ROOT/software/vmware.sh" \
        '/usr/src/kernels/$(uname -r)/scripts/sign-file'
    assert_file_contains "$REPO_ROOT/software/vmware.sh" 'Broadcom KB 315309'

    pass "software installers use Fedora-native packages and verified upstream paths"
}

test_x86_only_installers_reject_before_mutation() {
    local fakebin="$TEST_ROOT/unsupported/bin" calls="$TEST_ROOT/unsupported/calls"
    local script output status
    mkdir -p "$fakebin" "$TEST_ROOT/unsupported/home"
    : > "$calls"

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "--eval" ]]; then
    echo aarch64
    exit 0
fi
exit 1
EOF
    for command_name in akmods curl dnf kmodgenca mokutil sudo; do
        cat > "$fakebin/$command_name" <<'EOF'
#!/bin/bash
echo "$(basename "$0") $*" >> "$SOFTWARE_CALLS"
exit 99
EOF
    done
    chmod +x "$fakebin"/*

    for script in virtualbox vmware; do
        set +e
        output=$(HOME="$TEST_ROOT/unsupported/home" \
            PATH="$fakebin:/usr/bin:/bin" SOFTWARE_CALLS="$calls" \
            /bin/bash "$REPO_ROOT/software/$script.sh" 2>&1)
        status=$?
        set -e
        [[ "$status" -ne 0 ]] || fail "$script accepted an unsupported RPM architecture"
        [[ "$output" == *"x86_64"* ]] || fail "$script did not explain its host architecture requirement"
    done

    [[ ! -s "$calls" ]] \
        || fail "x86-only software installer mutated state before rejecting aarch64"
    pass "x86-only hypervisors reject unsupported RPM architectures before mutation"
}

test_inventory_and_update_ownership() {
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'software/boxes.sh|no|||needs systemd, KVM, libvirt networking, and a display; covered by software-regression.sh'
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'software/virtualbox.sh|no|||needs bare-metal kernel modules and Secure Boot firmware enrollment; covered by software-regression.sh'
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'software/vmware.sh|no|||needs a manual Broadcom download and bare-metal kernel modules; covered by software-regression.sh'
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'software/virtualbox.sh|VirtualBox and its akmod are maintained through the configured RPM Fusion repositories and DNF'
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'software/boxes.sh|Fedora virtualization packages are maintained through DNF'
    pass "software manifest and updater ownership stay synchronized"
}

test_fedora_software_contracts
test_x86_only_installers_reject_before_mutation
test_inventory_and_update_ownership

echo "✅ software regression checks passed"
