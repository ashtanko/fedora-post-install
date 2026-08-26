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

test_fedora_ide_contracts() {
    local script updater effective
    local -a package_aware=(
        android-studio cursor dbeaver jetbrains-toolbox nvim zed
    )

    for script in "${package_aware[@]}"; do
        grep -Fq 'source "$PKG_HELPER"' "$REPO_ROOT/ide/$script.sh" \
            || fail "$script.sh does not source lib/pkg.bash"
    done

    for script in "$REPO_ROOT"/ide/*.sh; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|\bsnap\b|add-apt-repository' \
            <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu package path"
        fi
        if grep -Eq '\bwget\b' <<< "$effective"; then
            fail "$(basename "$script") bypasses the retrying curl download contract"
        fi
    done

    while IFS= read -r updater; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$REPO_ROOT/updates/$updater")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|\bsnap\b' \
            <<< "$effective"; then
            fail "$updater retains a Debian/Ubuntu ownership path"
        fi
    done < <(awk -F'|' '$2 ~ /(^|,)ide\// { print $1 }' "$REPO_ROOT/updates/catalog.txt")

    pass "all IDE installers and their mapped updaters use Fedora package contracts"
}

test_package_and_release_mappings() {
    assert_file_contains "$REPO_ROOT/ide/cursor.sh" \
        'https://downloads.cursor.com/yumrepo'
    assert_file_contains "$REPO_ROOT/ide/cursor.sh" \
        '380FF4BCDC34A4BD92A3565342A1772E62E492D6'
    assert_file_contains "$REPO_ROOT/ide/cursor.sh" 'dnf_install cursor'
    assert_file_contains "$REPO_ROOT/ide/cursor.sh" \
        'grep -Fqx "Exec=$LEGACY_INSTALL_DIR/Cursor.AppImage --no-sandbox %F"'
    assert_file_contains "$REPO_ROOT/ide/dbeaver.sh" \
        'DBEAVER_APP_ID="io.dbeaver.DBeaverCommunity"'
    assert_file_contains "$REPO_ROOT/ide/dbeaver.sh" 'flatpak_install "$DBEAVER_APP_ID"'
    assert_file_contains "$REPO_ROOT/ide/nvim.sh" 'dnf_install neovim'
    assert_file_contains "$REPO_ROOT/ide/zed.sh" 'ZED_CHANNEL=preview sh "$ZED_INSTALLER"'
    assert_file_contains "$REPO_ROOT/ide/zed.sh" 'dnf_install curl'

    assert_file_contains "$REPO_ROOT/ide/jetbrains-toolbox.sh" 'aarch64) DOWNLOAD_KEY=linuxARM64'
    assert_file_contains "$REPO_ROOT/ide/jetbrains-toolbox.sh" 'checksumLink'
    assert_file_contains "$REPO_ROOT/ide/jetbrains-toolbox.sh" \
        'echo "$EXPECTED_SHA  $TMP/toolbox.tar.gz" | sha256sum --check --quiet'
    assert_file_contains "$REPO_ROOT/ide/jetbrains-toolbox.sh" \
        'dnf_install curl python3 tar libXi libXrender libXtst glx-utils'

    pass "IDE package, architecture, and verified-release mappings are explicit"
}

test_android_studio_verified_install_and_update() {
    local root="$TEST_ROOT/android" home="$TEST_ROOT/android/home"
    local fakebin="$TEST_ROOT/android/bin" archive="$TEST_ROOT/android/android-studio.tar.gz"
    local checksum archive_url
    mkdir -p "$home" "$fakebin" "$root/archive/android-studio/bin"
    archive_url="https://edgedl.me.gvt1.com/android/studio/ide-zips/test/android-studio-test-linux.tar.gz"

    cat > "$root/archive/android-studio/bin/studio.sh" <<'EOF'
#!/bin/bash
echo "Android Studio test"
EOF
    chmod +x "$root/archive/android-studio/bin/studio.sh"
    printf '{}\n' > "$root/archive/android-studio/product-info.json"
    tar -C "$root/archive" -czf "$archive" android-studio
    checksum="$(sha256sum "$archive" | awk '{print $1}')"

    cat > "$root/studio.html" <<EOF
<html><body>
<table><tr><td><button>android-studio-test-linux.tar.gz</button></td><td>1 MB</td><td>$checksum</td></tr></table>
<a href="$archive_url" id="agree-button__studio_linux_bundle_download">Download</a>
</body></html>
EOF

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == --eval ]]; then
    echo x86_64
    exit 0
fi
if [[ "${1:-}" == -q ]]; then
    exit 0
fi
exit 1
EOF
    cat > "$fakebin/curl" <<'EOF'
#!/bin/bash
out=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
printf '%s\n' "$url" >> "$IDE_TEST_CURL_LOG"
case "$url" in
    https://developer.android.com/studio) cp "$IDE_TEST_METADATA" "$out" ;;
    https://*/android/studio/ide-zips/*) cp "$IDE_TEST_ARCHIVE" "$out" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$fakebin/rpm" "$fakebin/curl"

    HOME="$home" PATH="$fakebin:/usr/bin:/bin" \
        IDE_TEST_METADATA="$root/studio.html" IDE_TEST_ARCHIVE="$archive" \
        IDE_TEST_CURL_LOG="$root/curl.log" \
        /bin/bash "$REPO_ROOT/ide/android-studio.sh" >/dev/null

    [ -x "$home/.local/share/android-studio/bin/studio.sh" ] \
        || fail "Android Studio fixture was not installed"
    [ "$(<"$home/.local/share/android-studio/.fpi-archive-sha256")" = "$checksum" ] \
        || fail "Android Studio did not retain its verified archive digest"

    HOME="$home" PATH="$fakebin:/usr/bin:/bin" \
        IDE_TEST_METADATA="$root/studio.html" IDE_TEST_ARCHIVE="$archive" \
        IDE_TEST_CURL_LOG="$root/curl.log" \
        /bin/bash "$REPO_ROOT/updates/update-android-studio.sh" >/dev/null
    [ "$(grep -Fxc "$archive_url" "$root/curl.log")" -eq 1 ] \
        || fail "current Android Studio updater downloaded the archive again"

    pass "Android Studio resolves, verifies, installs, and idempotently updates an official-style archive"
}

test_updater_ownership_and_docs() {
    [[ ! -e "$REPO_ROOT/updates/update-nvim.sh" ]] \
        || fail "Neovim still has a standalone updater despite DNF ownership"
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        "ide/nvim.sh|Fedora's current Neovim package is maintained through DNF"
    assert_file_contains "$REPO_ROOT/updates/update-android-studio.sh" \
        'FPI_ANDROID_STUDIO_UPDATE=1'
    assert_file_contains "$REPO_ROOT/tests/manifest.sh" \
        'ide/nvim.sh|yes||command -v nvim && rpm -q neovim'
    if grep -Eq 'update-nvim|NVIM_(VERSION|ARCHIVE|INSTALL_DIR)|CURSOR_INSTALL_DIR' \
        "$REPO_ROOT/.env.example" "$REPO_ROOT/docs/CONFIG.md" "$REPO_ROOT/docs/SCRIPTS.md"; then
        fail "retired IDE tarball/AppImage configuration remains documented"
    fi
    pass "IDE updater ownership, manifest coverage, and configuration docs agree"
}

test_fedora_ide_contracts
test_package_and_release_mappings
test_android_studio_verified_install_and_update
test_updater_ownership_and_docs

echo "✅ IDE regression checks passed"
