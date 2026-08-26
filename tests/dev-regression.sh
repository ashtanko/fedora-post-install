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

embedded_fingerprint() {
    local source_file="$1" key_file="$2"
    awk '
        /^-----BEGIN PGP PUBLIC KEY BLOCK-----$/ { capture=1 }
        capture { print }
        capture && /^-----END PGP PUBLIC KEY BLOCK-----$/ { exit }
    ' "$source_file" > "$key_file"
    gpg --batch --show-keys --with-colons --fingerprint "$key_file" 2>/dev/null \
        | awk -F: '$1 == "fpr" { print toupper($10); exit }'
}

test_fedora_dev_contracts() {
    local script effective
    local -a coupled_updaters=(
        update-aws-cli.sh update-bun.sh update-composer.sh update-deno.sh
        update-flutter.sh update-go.sh update-node.sh update-pipx-tools.sh
        update-pyenv.sh update-rbenv.sh update-rust.sh
    )

    for script in "$REPO_ROOT"/dev/*.sh; do
        # Match the literal helper variable used by each installer.
        # shellcheck disable=SC2016
        grep -Fq 'source "$PKG_HELPER"' "$script" \
            || fail "$(basename "$script") does not source lib/pkg.bash"
    done

    for script in "$REPO_ROOT"/dev/*.sh; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|ppa:|lsb_release|add-apt-repository' \
            <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu package path"
        fi
    done
    for script in "${coupled_updaters[@]}"; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$REPO_ROOT/updates/$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt|ppa:|lsb_release' \
            <<< "$effective"; then
            fail "$script retains a Debian/Ubuntu ownership or architecture path"
        fi
    done
    pass "all development installers and their coupled updaters use Fedora package contracts"
}

test_repository_and_package_mappings() {
    assert_file_contains "$REPO_ROOT/dev/azure-cli.sh" 'https://packages.microsoft.com/rhel/9/prod/'
    assert_file_contains "$REPO_ROOT/dev/azure-cli.sh" 'BC528686B50D79E339D3721CEB3E94ADBE1229CF'
    assert_file_contains "$REPO_ROOT/dev/docker.sh" '060A61C51B558A7F742B77AAC52FEB6B621E9F35'
    assert_file_contains "$REPO_ROOT/dev/gcloud.sh" '3749E1BA95A86CE054546ED2F09C394C3E1BA8D5'
    assert_file_contains "$REPO_ROOT/dev/gcloud.sh" "'3749E1BA95A86CE054546ED2F09C394C3E1BA8D5' 0"
    assert_file_contains "$REPO_ROOT/dev/gcloud.sh" 'dnf_install curl gnupg2 libxcrypt-compat'
    assert_file_contains "$REPO_ROOT/dev/kubernetes.sh" 'DE15B14486CD377B9E876E1A234654DA9A296436'
    assert_file_contains "$REPO_ROOT/dev/databases.sh" '4B0752C1BCA238C0B4EE14DC41DE058A4E7DCA05'
    assert_file_contains "$REPO_ROOT/dev/terraform.sh" '798AEC654E5C15428C8E42EEAA16FCBCA621E701'

    assert_file_contains "$REPO_ROOT/dev/databases.sh" 'dnf_install postgresql valkey mariadb sqlite pipx'
    assert_file_contains "$REPO_ROOT/dev/databases.sh" 'valkey-cli - Valkey'
    assert_file_contains "$REPO_ROOT/dev/podman.sh" 'podman podman-compose shadow-utils slirp4netns fuse-overlayfs container-selinux'
    assert_file_contains "$REPO_ROOT/dev/php.sh" 'php-cli php-common php-mbstring php-xml php-process php-mysqlnd php-pdo php-pecl-zip'
    assert_file_contains "$REPO_ROOT/dev/cpp.sh" 'dnf_group_install development-tools'
    assert_file_contains "$REPO_ROOT/dev/java.sh" 'PKG="java-${VERSION}-openjdk-devel"'
    assert_file_contains "$REPO_ROOT/dev/dotnet.sh" 'SDK_PACKAGE="dotnet-sdk-${DOTNET_VERSION}"'
    assert_file_contains "$REPO_ROOT/dev/kubernetes.sh" 'KUBERNETES_MINOR="${KUBERNETES_MINOR:-v1.36}"'
    pass "development package and signed repository mappings are pinned"
}

test_detached_signature_contracts() {
    local ssm_key="$TEST_ROOT/ssm.asc" tfsec_key="$TEST_ROOT/tfsec.asc"
    local verify_line install_line

    [[ "$(embedded_fingerprint "$REPO_ROOT/dev/aws-cli.sh" "$ssm_key")" \
        == '7959637124CE093AD501D47A2C4D4AFF6F6757EE' ]] \
        || fail "AWS Session Manager embeds an unexpected signing key"
    [[ "$(embedded_fingerprint "$REPO_ROOT/dev/terraform.sh" "$tfsec_key")" \
        == 'D66B222A3EA4C25D5D1A097FC34ACEFB46EC39CE' ]] \
        || fail "tfsec embeds an unexpected signing key"

    verify_line=$(grep -nF 'gpg --batch --homedir "$SSM_GNUPGHOME" --verify' \
        "$REPO_ROOT/dev/aws-cli.sh" | cut -d: -f1)
    install_line=$(grep -nF 'sudo dnf -q install' "$REPO_ROOT/dev/aws-cli.sh" | cut -d: -f1)
    [[ -n "$verify_line" && -n "$install_line" && "$verify_line" -lt "$install_line" ]] \
        || fail "Session Manager RPM is not verified before DNF installation"

    verify_line=$(grep -nF 'gpg --batch --homedir "$TFSEC_GNUPGHOME" --verify' \
        "$REPO_ROOT/dev/terraform.sh" | cut -d: -f1)
    install_line=$(grep -nF 'sudo install -m 0755 "$TFSEC_BIN"' \
        "$REPO_ROOT/dev/terraform.sh" | cut -d: -f1)
    [[ -n "$verify_line" && -n "$install_line" && "$verify_line" -lt "$install_line" ]] \
        || fail "tfsec binary is not verified before privileged installation"
    pass "AWS Session Manager and tfsec verify fingerprint-pinned detached signatures"
}

test_java_package_selection() {
    local fakebin="$TEST_ROOT/java/bin" calls="$TEST_ROOT/java/calls" version
    mkdir -p "$fakebin" "$TEST_ROOT/java/home"
    : > "$calls"

    cat > "$fakebin/rpm" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == --eval ]]; then echo x86_64; exit 0; fi
if [[ "${1:-}" == -q ]]; then exit 1; fi
exit 1
EOF
    cat > "$fakebin/dnf" <<'EOF'
#!/bin/bash
echo "dnf $*" >> "$DEV_TEST_CALLS"
EOF
    cat > "$fakebin/sudo" <<'EOF'
#!/bin/bash
echo "sudo $*" >> "$DEV_TEST_CALLS"
exec "$@"
EOF
    cat > "$fakebin/java" <<'EOF'
#!/bin/bash
echo 'openjdk version "test"' >&2
EOF
    chmod +x "$fakebin"/*

    for version in 8 21; do
        HOME="$TEST_ROOT/java/home" PATH="$fakebin:/usr/bin:/bin" DEV_TEST_CALLS="$calls" \
            JAVA_VERSION="$version" /bin/bash "$REPO_ROOT/dev/java.sh" >/dev/null 2>&1
        assert_file_contains "$calls" "sudo dnf -q install -y --setopt=install_weak_deps=False java-${version}-openjdk-devel"
    done
    pass "Java selections map to Fedora OpenJDK development packages"
}

test_update_ownership() {
    assert_file_contains "$REPO_ROOT/updates/update-composer.sh" 'rpm -qf "$COMPOSER_BIN"'
    assert_file_contains "$REPO_ROOT/updates/update-go.sh" 'ARCH=$(release_arch)'
    if grep -Fq 'podman-compose' "$REPO_ROOT/updates/update-pipx-tools.sh"; then
        fail "pipx updater still claims Fedora-owned podman-compose"
    fi
    if grep -Fq 'dev/podman.sh' "$REPO_ROOT/updates/catalog.txt"; then
        fail "Podman installer remains mapped to the pipx updater"
    fi
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'dev/podman.sh|Fedora'"'"'s Podman and podman-compose packages are maintained through DNF'

    local conflict_line repo_line
    conflict_line=$(grep -nF 'dnf_installed podman-docker' "$REPO_ROOT/dev/docker.sh" | cut -d: -f1)
    repo_line=$(grep -nF 'repo_add docker-ce' "$REPO_ROOT/dev/docker.sh" | cut -d: -f1)
    [[ -n "$conflict_line" && -n "$repo_line" && "$conflict_line" -lt "$repo_line" ]] \
        || fail "Docker does not reject the podman-docker conflict before repository mutation"
    pass "updater ownership follows Fedora RPM provenance and Docker detects its CLI conflict early"
}

test_fedora_dev_contracts
test_repository_and_package_mappings
test_detached_signature_contracts
test_java_package_selection
test_update_ownership

echo "✅ development regression checks passed"
