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

assert_archive_contains() {
    local archive="$1" path="$2"
    grep -Fqx -- "$path" < <(unzip -Z1 "$archive") \
        || fail "expected $archive to contain: $path"
}

assert_archive_excludes() {
    local archive="$1" pattern="$2"
    if grep -Eq -- "$pattern" < <(unzip -Z1 "$archive"); then
        fail "expected $archive to exclude pattern: $pattern"
    fi
}

make_rpm_stub() {
    local target="$1"
    cat > "$target" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == -q && "${2:-}" == --quiet && "${3:-}" == zip ]]; then
    exit 0
fi
exit 1
EOF
    chmod +x "$target"
}

test_fedora_mobile_contract() {
    local effective
    assert_file_contains "$REPO_ROOT/mobile/zip_flutter_plugin.sh" 'source "$PKG_HELPER"'
    assert_file_contains "$REPO_ROOT/mobile/zip_flutter_plugin.sh" 'load_config "$REPO_ROOT"'
    assert_file_contains "$REPO_ROOT/mobile/zip_flutter_plugin.sh" 'dnf_install zip'
    assert_file_contains "$REPO_ROOT/mobile/zip_flutter_plugin.sh" \
        'TMP="$(mktemp -d "$OUTPUT_DIR/.flutter-plugin-archive.XXXXXX")"'
    assert_file_contains "$REPO_ROOT/mobile/zip_flutter_plugin.sh" \
        'mv -f -- "$TMP_ARCHIVE" "$OUTPUT_PATH"'

    effective="$(sed -E 's/[[:space:]]+#.*$//' "$REPO_ROOT/mobile/zip_flutter_plugin.sh")"
    if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|\bsnap\b|\bwget\b' \
        <<< "$effective"; then
        fail "mobile utility retains a Debian/Ubuntu package path"
    fi

    pass "mobile utility uses the Fedora package and shared script contracts"
}

test_archive_contents_and_replacement() {
    local root="$TEST_ROOT/archive" plugin="$TEST_ROOT/archive/plugin"
    local fakebin="$TEST_ROOT/archive/bin" archive="$TEST_ROOT/archive/output/plugin.zip"
    local original_sha
    mkdir -p "$plugin/lib" "$plugin/android/src" "$plugin/android/.gradle" \
        "$plugin/example/build" "$plugin/.dart_tool" "$plugin/.git" "$plugin/coverage" "$fakebin"
    make_rpm_stub "$fakebin/rpm"

    printf 'name: fixture\n' > "$plugin/pubspec.yaml"
    printf 'first\n' > "$plugin/lib/first.dart"
    printf 'keep\n' > "$plugin/android/src/keep.kt"
    printf 'exclude\n' > "$plugin/android/local.properties"
    printf 'exclude\n' > "$plugin/android/.gradle/state"
    printf 'exclude\n' > "$plugin/example/build/output"
    printf 'exclude\n' > "$plugin/.dart_tool/package_config.json"
    printf 'exclude\n' > "$plugin/.git/config"
    printf 'exclude\n' > "$plugin/coverage/lcov.info"
    printf 'exclude\n' > "$plugin/pubspec.lock"

    HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" \
        /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" "$plugin" "$archive" >/dev/null

    assert_archive_contains "$archive" "pubspec.yaml"
    assert_archive_contains "$archive" "lib/first.dart"
    assert_archive_contains "$archive" "android/src/keep.kt"
    assert_archive_excludes "$archive" '(^|/)(build|\.dart_tool|\.git|coverage)/'
    assert_archive_excludes "$archive" '(^|/)pubspec\.lock$'
    assert_archive_excludes "$archive" '^android/(\.gradle/|local\.properties$)'

    original_sha="$(sha256sum "$archive" | awk '{print $1}')"
    cat > "$fakebin/zip" <<'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$fakebin/zip"
    if HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" \
        /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" "$plugin" "$archive" >/dev/null 2>&1; then
        fail "failed zip command was reported as successful"
    fi
    [ "$(sha256sum "$archive" | awk '{print $1}')" = "$original_sha" ] \
        || fail "failed zip command replaced the previous archive"
    rm "$fakebin/zip"

    rm "$plugin/lib/first.dart"
    printf 'second\n' > "$plugin/lib/second.dart"
    HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" \
        /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" "$plugin" "$archive" >/dev/null
    assert_archive_contains "$archive" "lib/second.dart"
    assert_archive_excludes "$archive" '^lib/first\.dart$'

    (
        cd "$plugin"
        HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" \
            /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" . >/dev/null
        HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" \
            /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" . >/dev/null
    )
    assert_archive_contains "$plugin/plugin_distribution.zip" "lib/second.dart"
    assert_archive_excludes "$plugin/plugin_distribution.zip" \
        '(^|/)(plugin_distribution\.zip|\.flutter-plugin-archive\.)'

    pass "Flutter plugin archives exclude generated state, their own output, and stale entries"
}

test_invalid_paths_fail_before_package_mutation() {
    local root="$TEST_ROOT/invalid" fakebin="$TEST_ROOT/invalid/bin"
    local plugin="$TEST_ROOT/invalid/plugin" output status
    mkdir -p "$fakebin" "$plugin"
    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
echo "rpm $*" >> "$MOBILE_PACKAGE_LOG"
exit 1
EOF
    chmod +x "$fakebin/rpm"
    : > "$root/package.log"

    set +e
    output=$(HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" MOBILE_PACKAGE_LOG="$root/package.log" \
        /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" "$root/missing" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || fail "missing plugin path was accepted"
    [[ "$output" == *"directory not found"* ]] || fail "missing plugin path was not explained"
    [ ! -s "$root/package.log" ] || fail "missing plugin path triggered package checks"

    set +e
    output=$(HOME="$root/home" PATH="$fakebin:/usr/bin:/bin" MOBILE_PACKAGE_LOG="$root/package.log" \
        /bin/bash "$REPO_ROOT/mobile/zip_flutter_plugin.sh" "$plugin" "$plugin" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || fail "directory archive output was accepted"
    [[ "$output" == *"output is a directory"* ]] || fail "directory output path was not explained"
    [ ! -s "$root/package.log" ] || fail "directory output path triggered package checks"

    pass "invalid source and directory output paths fail before package or archive mutation"
}

test_manual_inventory() {
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'mobile/zip_flutter_plugin.sh|no|||manual Fedora archive utility; covered by mobile-regression.sh'
    if grep -Fq 'mobile/zip_flutter_plugin.sh' "$REPO_ROOT/config/catalog.txt"; then
        fail "manual mobile utility was added to the interactive installer catalog"
    fi
    if grep -Fq 'mobile/zip_flutter_plugin.sh' "$REPO_ROOT/updates/catalog.txt"; then
        fail "manual archive utility was assigned a software updater"
    fi
    pass "mobile utility remains manual with synchronized manifest and updater disposition"
}

test_fedora_mobile_contract
test_archive_contents_and_replacement
test_invalid_paths_fail_before_package_mutation
test_manual_inventory

echo "✅ mobile regression checks passed"
