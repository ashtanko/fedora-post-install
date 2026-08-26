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

test_fedora_app_contracts() {
    local script effective

    for script in "$REPO_ROOT"/apps/*.sh; do
        # Match the literal helper variable used by each installer.
        # shellcheck disable=SC2016
        grep -Fq 'source "$PKG_HELPER"' "$script" \
            || fail "$(basename "$script") does not source lib/pkg.bash"
    done

    for script in "$REPO_ROOT"/apps/*.sh \
        "$REPO_ROOT/updates/update-vscode.sh" \
        "$REPO_ROOT/updates/update-vscode-extensions.sh"; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get)?\b|\bdpkg\b|\.deb\b|/etc/apt|snap install' <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu package path"
        fi
    done

    assert_file_contains "$REPO_ROOT/apps/browsers.sh" \
        'https://dl.google.com/linux/chrome/rpm/stable/x86_64'
    assert_file_contains "$REPO_ROOT/apps/browsers.sh" \
        'EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796'
    assert_file_contains "$REPO_ROOT/apps/browsers.sh" 'dnf_install google-chrome-stable'

    assert_file_contains "$REPO_ROOT/apps/vscode.sh" \
        'https://packages.microsoft.com/yumrepos/vscode'
    assert_file_contains "$REPO_ROOT/apps/vscode.sh" \
        'BC528686B50D79E339D3721CEB3E94ADBE1229CF'
    assert_file_contains "$REPO_ROOT/apps/vscode.sh" 'dnf_install code'

    assert_file_contains "$REPO_ROOT/apps/warp.sh" \
        'https://releases.warp.dev/linux/rpm/stable'
    assert_file_contains "$REPO_ROOT/apps/warp.sh" \
        '0913165C78D5B7A41B42AC657FF7AB39D60F803F'
    assert_file_contains "$REPO_ROOT/apps/warp.sh" 'dnf_install warp-terminal'

    assert_file_contains "$REPO_ROOT/apps/guake.sh" 'dnf_install guake'
    assert_file_contains "$REPO_ROOT/apps/flameshot.sh" 'dnf_install flameshot'
    pass "app installers use Fedora packages and pinned vendor RPM repositories"
}

test_x86_only_installers_reject_before_mutation() {
    local fakebin="$TEST_ROOT/unsupported/bin" calls="$TEST_ROOT/unsupported/calls"
    local script status
    mkdir -p "$fakebin" "$TEST_ROOT/unsupported/home"
    : > "$calls"

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "--eval" ]]; then
    echo aarch64
    exit 0
fi
echo "rpm $*" >> "$APPS_CALLS"
exit 1
EOF
    for command_name in curl dnf sudo; do
        cat > "$fakebin/$command_name" <<'EOF'
#!/bin/bash
echo "$(basename "$0") $*" >> "$APPS_CALLS"
exit 99
EOF
    done
    chmod +x "$fakebin"/*

    for script in browsers bitwarden-cli; do
        set +e
        HOME="$TEST_ROOT/unsupported/home" PATH="$fakebin:/usr/bin:/bin" APPS_CALLS="$calls" \
            /bin/bash "$REPO_ROOT/apps/$script.sh" >/dev/null 2>&1
        status=$?
        set -e
        [[ "$status" -ne 0 ]] || fail "$script accepted aarch64 despite its x86-only vendor build"
    done

    [[ ! -s "$calls" ]] || fail "x86-only installer mutated package or repository state before rejecting aarch64"
    pass "x86-only vendor builds reject unsupported RPM architectures before mutation"
}

test_postman_arm_install_is_transactional_and_idempotent() {
    local fakebin="$TEST_ROOT/postman/bin"
    local fixture_root="$TEST_ROOT/postman/fixture" archive="$TEST_ROOT/postman/postman.tar.gz"
    local install_dir="$TEST_ROOT/postman/home/.local/share/Postman"
    local calls="$TEST_ROOT/postman/calls" status
    mkdir -p "$fakebin" "$fixture_root/Postman/app/icons" "$TEST_ROOT/postman/home"
    : > "$calls"

    cat > "$fixture_root/Postman/Postman" <<'EOF'
#!/bin/bash
echo 'Postman fixture'
EOF
    chmod +x "$fixture_root/Postman/Postman"
    : > "$fixture_root/Postman/app/icons/icon_128x128.png"
    tar -czf "$archive" -C "$fixture_root" Postman

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "--eval" ]]; then
    echo aarch64
    exit 0
fi
if [[ "${1:-}" == "-q" && "${2:-}" == "--quiet" ]]; then
    exit 0
fi
exit 1
EOF
    cat > "$fakebin/curl" <<'EOF'
#!/bin/bash
output=""
url=""
while (( $# )); do
    case "$1" in
        -o) output="$2"; shift 2 ;;
        http*) url="$1"; shift ;;
        *) shift ;;
    esac
done
printf 'curl %s\n' "$url" >> "$APPS_CALLS"
cp "$POSTMAN_TEST_ARCHIVE" "$output"
EOF
    chmod +x "$fakebin"/*

    HOME="$TEST_ROOT/postman/home" PATH="$fakebin:/usr/bin:/bin" APPS_CALLS="$calls" \
        POSTMAN_TEST_ARCHIVE="$archive" POSTMAN_INSTALL_DIR="$install_dir" \
        /bin/bash "$REPO_ROOT/apps/postman.sh" >/dev/null

    [[ -x "$install_dir/Postman" ]] || fail "Postman ARM archive was not activated"
    [[ -L "$TEST_ROOT/postman/home/.local/bin/postman" ]] \
        || fail "Postman command symlink was not created"
    assert_file_contains "$calls" 'https://dl.pstmn.io/download/latest/linux_arm64'
    if find "$(dirname "$install_dir")" -maxdepth 1 -name '.postman-stage.*' -print -quit \
        | grep -q .; then
        fail "Postman left a staging directory after activation"
    fi

    : > "$calls"
    HOME="$TEST_ROOT/postman/home" PATH="$fakebin:/usr/bin:/bin" APPS_CALLS="$calls" \
        POSTMAN_TEST_ARCHIVE="$archive" POSTMAN_INSTALL_DIR="$install_dir" \
        /bin/bash "$REPO_ROOT/apps/postman.sh" >/dev/null
    [[ ! -s "$calls" ]] || fail "Postman downloaded again after a successful installation"

    mkdir -p "$TEST_ROOT/postman/incomplete"
    : > "$calls"
    set +e
    HOME="$TEST_ROOT/postman/home" PATH="$fakebin:/usr/bin:/bin" APPS_CALLS="$calls" \
        POSTMAN_TEST_ARCHIVE="$archive" POSTMAN_INSTALL_DIR="$TEST_ROOT/postman/incomplete" \
        /bin/bash "$REPO_ROOT/apps/postman.sh" >/dev/null 2>&1
    status=$?
    set -e
    [[ "$status" -ne 0 ]] || fail "Postman overwrote an incomplete existing installation path"
    [[ ! -s "$calls" ]] || fail "Postman downloaded before rejecting an existing incomplete path"
    pass "Postman uses ARM mapping, transactional activation, and safe re-runs"
}

test_fedora_app_contracts
test_x86_only_installers_reject_before_mutation
test_postman_arm_install_is_transactional_and_idempotent

echo "✅ apps regression checks passed"
