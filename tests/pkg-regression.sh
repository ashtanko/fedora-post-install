#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO_ROOT/lib/pkg.bash"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAKEBIN="$TMP/bin"
CALL_LOG="$TMP/calls.log"
CAPTURE_ROOT="$TMP/captured-root"
mkdir -p "$FAKEBIN" "$CAPTURE_ROOT"
: >"$CALL_LOG"

fail() {
    echo "❌ $*" >&2
    exit 1
}

assert_equal() {
    local expected="$1" actual="$2"
    [[ "$actual" == "$expected" ]] \
        || fail "expected '$expected', got '$actual'"
}

assert_log() {
    local expected="$1"
    grep -Fqx -- "$expected" "$CALL_LOG" \
        || fail "missing call '$expected' in $CALL_LOG"
}

assert_no_sudo_calls() {
    if grep -q '^sudo:' "$CALL_LOG"; then
        fail "unexpected privileged command after validation failure"
    fi
}

cat >"$FAKEBIN/dnf" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == --version ]]; then
    printf '%s\n' "${DNF_TEST_VERSION:-dnf5 version 5.2.0}"
    exit 0
fi
printf 'dnf:%s\n' "$*" >>"$PKG_TEST_CALL_LOG"
EOF

cat >"$FAKEBIN/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == --eval ]]; then
    printf '%s\n' "${RPM_TEST_ARCH:-x86_64}"
    exit 0
fi
if [[ "${1:-}" == -q ]]; then
    package="${*: -1}"
    case " ${RPM_TEST_INSTALLED:-} " in
        *" $package "*) exit 0 ;;
        *) exit 1 ;;
    esac
fi
if [[ "${1:-}" == --import ]]; then
    printf 'rpm:%s\n' "$*" >>"$PKG_TEST_CALL_LOG"
    exit 0
fi
exit 1
EOF

cat >"$FAKEBIN/sudo" <<'EOF'
#!/bin/bash
printf 'sudo:%s\n' "$*" >>"$PKG_TEST_CALL_LOG"
case "${1:-}" in
    dnf|rpm|restorecon)
        exec "$@"
        ;;
    install)
        if [[ " $* " == *" -d "* ]]; then
            exit 0
        fi
        source_file="${*: -2:1}"
        target_file="${*: -1}"
        captured="$PKG_TEST_CAPTURE_ROOT$target_file"
        mkdir -p "$(dirname "$captured")"
        cp "$source_file" "$captured"
        ;;
    *)
        exit 1
        ;;
esac
EOF

cat >"$FAKEBIN/curl" <<'EOF'
#!/bin/bash
output=""
while (( $# > 0 )); do
    case "$1" in
        -o) output="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[[ -n "$output" ]]
cp "$PKG_TEST_KEY_SOURCE" "$output"
printf 'curl:%s\n' "$output" >>"$PKG_TEST_CALL_LOG"
EOF

cat >"$FAKEBIN/gpg" <<'EOF'
#!/bin/bash
IFS=',' read -ra fingerprints <<<"${PKG_TEST_FINGERPRINTS:-}"
for fingerprint in "${fingerprints[@]}"; do
    [[ -n "$fingerprint" ]] || continue
    printf 'pub:-:4096:1:0000000000000000:0:0::::::\n'
    printf 'fpr:::::::::%s:\n' "$fingerprint"
done
EOF

cat >"$FAKEBIN/flatpak" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == info && "${FLATPAK_TEST_INSTALLED:-no}" == yes ]]; then
    exit 0
fi
if [[ "${1:-}" == info ]]; then
    exit 1
fi
printf 'flatpak:%s\n' "$*" >>"$PKG_TEST_CALL_LOG"
EOF

cat >"$FAKEBIN/restorecon" <<'EOF'
#!/bin/bash
printf 'restorecon:%s\n' "$*" >>"$PKG_TEST_CALL_LOG"
EOF

chmod +x "$FAKEBIN"/*
export PATH="$FAKEBIN:$PATH"
export PKG_TEST_CALL_LOG="$CALL_LOG"
export PKG_TEST_CAPTURE_ROOT="$CAPTURE_ROOT"

# shellcheck source=../lib/pkg.bash
source "$HELPER"

assert_equal 4 "$(DNF_TEST_VERSION=4.21.1 dnf_major)"
assert_equal 5 "$(DNF_TEST_VERSION='dnf5 version 5.2.0' dnf_major)"
if DNF_TEST_VERSION=6.0.0 dnf_major >/dev/null 2>&1; then
    fail "dnf_major accepted an unsupported major version"
fi

assert_equal x86_64 "$(RPM_TEST_ARCH=x86_64 rpm_arch)"
assert_equal aarch64 "$(RPM_TEST_ARCH=aarch64 rpm_arch)"
assert_equal amd64 "$(RPM_TEST_ARCH=x86_64 release_arch)"
assert_equal arm64 "$(RPM_TEST_ARCH=aarch64 release_arch)"
if RPM_TEST_ARCH=ppc64le rpm_arch >/dev/null 2>&1; then
    fail "rpm_arch accepted an unsupported architecture"
fi

: >"$CALL_LOG"
RPM_TEST_INSTALLED=git dnf_install git curl
assert_log 'sudo:dnf -q install -y --setopt=install_weak_deps=False curl'
assert_log 'dnf:-q install -y --setopt=install_weak_deps=False curl'

: >"$CALL_LOG"
RPM_TEST_INSTALLED='git curl' dnf_install git curl
[[ ! -s "$CALL_LOG" ]] || fail "dnf_install ran a transaction for installed packages"

: >"$CALL_LOG"
DNF_TEST_VERSION=4.21.1 dnf_group_install development-tools
assert_log 'dnf:-q groupinstall -y --setopt=install_weak_deps=False development-tools'

: >"$CALL_LOG"
DNF_TEST_VERSION='dnf5 version 5.2.0' dnf_group_install development-tools
assert_log 'dnf:-q group install -y --setopt=install_weak_deps=False development-tools'

: >"$CALL_LOG"
RPM_TEST_INSTALLED=dnf-plugins-core copr_enable owner/project
assert_log 'dnf:-q copr enable -y owner/project'
if copr_enable '../owner/project' >/dev/null 2>&1; then
    fail "copr_enable accepted an unsafe project name"
fi

: >"$CALL_LOG"
FLATPAK_TEST_INSTALLED=no flatpak_install org.example.App
assert_log 'flatpak:remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo'
assert_log 'flatpak:install --user -y flathub org.example.App'

: >"$CALL_LOG"
FLATPAK_TEST_INSTALLED=yes flatpak_install org.example.App
[[ ! -s "$CALL_LOG" ]] || fail "flatpak_install changed an installed application"

fingerprint='0123456789ABCDEF0123456789ABCDEF01234567'
key_fixture="$TMP/repository-key.asc"
repo_baseurl="https://packages.example.test/\$releasever/\$basearch"
printf 'test key material\n' >"$key_fixture"
export PKG_TEST_KEY_SOURCE="$key_fixture"

: >"$CALL_LOG"
PKG_TEST_FINGERPRINTS="$fingerprint" repo_add example \
    "$repo_baseurl" \
    'https://packages.example.test/key.asc' \
    '0123 4567 89ab cdef 0123 4567 89ab cdef 0123 4567'
assert_log 'sudo:install -d -m 0755 /etc/yum.repos.d /etc/pki/rpm-gpg'
assert_log 'sudo:rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-example'
assert_log 'sudo:restorecon /etc/pki/rpm-gpg/RPM-GPG-KEY-example /etc/yum.repos.d/example.repo'
repo_capture="$CAPTURE_ROOT/etc/yum.repos.d/example.repo"
grep -Fqx 'gpgcheck=1' "$repo_capture" || fail "repo_add omitted gpgcheck=1"
grep -Fqx 'repo_gpgcheck=1' "$repo_capture" || fail "repo_add omitted repo_gpgcheck=1"
grep -Fqx "baseurl=$repo_baseurl" "$repo_capture" \
    || fail "repo_add did not preserve DNF URL variables"

: >"$CALL_LOG"
PKG_TEST_FINGERPRINTS='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
    repo_add mismatch https://packages.example.test/repo \
        https://packages.example.test/key.asc "$fingerprint" >/dev/null 2>&1 \
    && fail "repo_add accepted the wrong fingerprint"
assert_no_sudo_calls

: >"$CALL_LOG"
PKG_TEST_FINGERPRINTS="$fingerprint,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" \
    repo_add multiple https://packages.example.test/repo \
        https://packages.example.test/key.asc "$fingerprint" >/dev/null 2>&1 \
    && fail "repo_add imported a key file containing multiple primary keys"
assert_no_sudo_calls

: >"$CALL_LOG"
PKG_TEST_FINGERPRINTS="$fingerprint" \
    repo_add '../unsafe' https://packages.example.test/repo \
        https://packages.example.test/key.asc "$fingerprint" >/dev/null 2>&1 \
    && fail "repo_add accepted an unsafe repository name"
assert_no_sudo_calls

echo "✅ Fedora package helper regression checks passed"
