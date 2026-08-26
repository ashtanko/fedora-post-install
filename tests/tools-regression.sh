#!/bin/bash
# shellcheck disable=SC2016
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

assert_file_contains() {
    local file="$1" needle="$2"
    grep -Fq -- "$needle" "$file" || fail "expected $file to contain: $needle"
}

test_fedora_tools_contracts() {
    local script updater effective
    local -a package_aware=(
        atuin btop cli-tools ctop dive dotfiles fish fonts gitleaks hadolint
        just lazydocker modern-cli network-tools pre-commit-setup rclone restic
        starship system-maintenance tmux-config trivy wireshark yq zsh
    )

    for script in "${package_aware[@]}"; do
        # Match the literal helper variable used by each installer.
        # shellcheck disable=SC2016
        grep -Fq 'source "$PKG_HELPER"' "$REPO_ROOT/tools/$script.sh" \
            || fail "$script.sh does not source lib/pkg.bash"
    done

    for script in "$REPO_ROOT"/tools/*.sh; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$script")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query|-reconfigure)?\b|\.deb\b|/etc/apt|debconf|add-apt-repository|\bsnap\b' \
            <<< "$effective"; then
            fail "$(basename "$script") retains a Debian/Ubuntu package path"
        fi
        if grep -Eq '\bwget\b' <<< "$effective"; then
            fail "$(basename "$script") bypasses the retrying curl download contract"
        fi
    done

    while IFS= read -r updater; do
        effective="$(sed -E 's/[[:space:]]+#.*$//' "$REPO_ROOT/updates/$updater")"
        if grep -En '\bapt(-get|-cache)?\b|\bdpkg(-query)?\b|\.deb\b|/etc/apt' <<< "$effective"; then
            fail "$updater retains a Debian/Ubuntu ownership or architecture path"
        fi
        if grep -Eq '\bwget\b' <<< "$effective"; then
            fail "$updater bypasses the retrying curl download contract"
        fi
    done < <(awk -F'|' '$2 ~ /(^|,)tools\// { print $1 }' "$REPO_ROOT/updates/catalog.txt")

    pass "all tools installers and their mapped updaters use Fedora package contracts"
}

test_package_and_release_mappings() {
    assert_file_contains "$REPO_ROOT/tools/cli-tools.sh" \
        'dnf_install bat fzf ripgrep eza jq htop tmux tree gh'
    assert_file_contains "$REPO_ROOT/tools/modern-cli.sh" \
        'dnf_install btop direnv hyperfine git-delta fd-find zoxide du-dust tealdeer'
    assert_file_contains "$REPO_ROOT/tools/network-tools.sh" \
        'dnf_install mtr traceroute nmap bind-utils iproute lsof nmap-ncat iperf3 httpie whois'
    assert_file_contains "$REPO_ROOT/tools/rclone.sh" 'dnf_install rclone'
    assert_file_contains "$REPO_ROOT/tools/restic.sh" 'dnf_install restic'
    assert_file_contains "$REPO_ROOT/tools/dotfiles.sh" 'dnf_install chezmoi'
    assert_file_contains "$REPO_ROOT/tools/gitleaks.sh" 'dnf_install gitleaks'
    assert_file_contains "$REPO_ROOT/tools/hadolint.sh" 'dnf_install hadolint'
    assert_file_contains "$REPO_ROOT/tools/just.sh" 'dnf_install just'
    assert_file_contains "$REPO_ROOT/tools/pre-commit-setup.sh" 'dnf_install pre-commit'
    assert_file_contains "$REPO_ROOT/tools/yq.sh" 'dnf_install yq'

    if grep -Eq 'batcat|fdfind' "$REPO_ROOT/tools/cli-tools.sh" "$REPO_ROOT/tools/modern-cli.sh" \
        "$REPO_ROOT/tests/verify/tools_cli-tools.sh" "$REPO_ROOT/tests/verify/tools_modern-cli.sh"; then
        fail "Fedora-unnecessary batcat/fdfind compatibility remains"
    fi

    assert_file_contains "$REPO_ROOT/tools/dive.sh" \
        'DIVE_ASSET="dive_${DIVE_NUM}_linux_${ARCH}.rpm"'
    assert_file_contains "$REPO_ROOT/tools/dive.sh" 'ARCH=$(release_arch)'
    assert_file_contains "$REPO_ROOT/tools/starship.sh" 'STARSHIP_ARCH=$(rpm_arch)'
    assert_file_contains "$REPO_ROOT/tools/atuin.sh" 'ATUIN_ARCH=$(rpm_arch)'
    assert_file_contains "$REPO_ROOT/tools/atuin.sh" \
        'ATUIN_ASSET="atuin-${ATUIN_ARCH}-unknown-linux-gnu.tar.gz"'
    pass "Fedora packages and verified release asset mappings are explicit"
}

test_repository_and_capture_security() {
    assert_file_contains "$REPO_ROOT/tools/trivy.sh" \
        '825AD9036F7C850E6A6FED4935B8ACA44FD9CA9F'
    assert_file_contains "$REPO_ROOT/tools/trivy.sh" \
        'https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/'
    assert_file_contains "$REPO_ROOT/tools/trivy.sh" 'dnf_install trivy'

    assert_file_contains "$REPO_ROOT/tools/wireshark.sh" \
        'dnf_install wireshark wireshark-cli libcap shadow-utils'
    assert_file_contains "$REPO_ROOT/tools/wireshark.sh" \
        'sudo setcap cap_net_raw,cap_net_admin=eip "$DUMPCAP_BIN"'
    assert_file_contains "$REPO_ROOT/tools/wireshark.sh" \
        'sudo usermod -aG wireshark "$CURRENT_USER"'
    pass "Trivy repository trust and Wireshark capture permissions are pinned"
}

test_updater_ownership() {
    local package_tool
    for package_tool in chezmoi gitleaks just rclone restic yq; do
        [[ ! -e "$REPO_ROOT/updates/update-${package_tool}.sh" ]] \
            || fail "$package_tool still has a standalone updater despite DNF ownership"
    done
    for package_tool in gitleaks hadolint just rclone restic yq; do
        assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
            "tools/${package_tool}.sh|Fedora package is maintained through DNF"
    done
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'tools/dotfiles.sh|Fedora chezmoi package is maintained through DNF'
    assert_file_contains "$REPO_ROOT/updates/skipped.txt" \
        'tools/pre-commit-setup.sh|Fedora pre-commit package is maintained through DNF'
    assert_file_contains "$REPO_ROOT/updates/update-atuin.sh" 'FPI_ATUIN_UPDATE=1'
    assert_file_contains "$REPO_ROOT/tools/atuin.sh" 'sha256sum --check --quiet'
    assert_file_contains "$REPO_ROOT/updates/update-dive.sh" \
        'rpm -qf --qf '\''%{NAME}\n'\'' "$DIVE_BIN"'
    assert_file_contains "$REPO_ROOT/updates/update-dive.sh" \
        'DIVE_ASSET="dive_${DIVE_NUM}_linux_${ARCH}.rpm"'
    pass "tool updaters follow Fedora RPM and standalone release ownership"
}

test_fedora_tools_contracts
test_package_and_release_mappings
test_repository_and_capture_security
test_updater_ownership

echo "✅ tools regression checks passed"
