#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail() {
    echo "❌ $*" >&2
    exit 1
}

legacy_pattern='ubuntu-post-install|UBUNTU_POST_INSTALL|\.env-ubuntu-post-install|ubuntu-setup|Ubuntu Dev Environment Setup|Ubuntu Post Install|UBUNTU POST INSTALL|UPI_|__upi|99-upi-|/upi-'
if grep -REn \
    --exclude='FEDORA-MIGRATION-PROMPT.md' \
    --exclude='FEDORA-MIGRATION.md' \
    --exclude='identity-regression.sh' \
    --exclude-dir='.git' \
    --exclude-dir='.omx' \
    --exclude-dir='dist' \
    "$legacy_pattern" .; then
    fail "legacy Ubuntu project identity remains outside the migration records"
fi

[[ ! -e cmd/ubuntu-post-install-tui ]] \
    || fail "legacy TUI directory still exists"
[[ -f cmd/fedora-post-install-tui/main.go ]] \
    || fail "Fedora TUI source directory is missing"
grep -Fqx 'module github.com/ashtanko/fedora-post-install' go.mod \
    || fail "Go module path does not use the Fedora project identity"
grep -Fq "REPO=\"\${REPO:-ashtanko/fedora-post-install}\"" install.sh \
    || fail "installer repository default does not use the Fedora slug"
grep -Fq "PREFIX=\"\${PREFIX:-\$HOME/.local/share/fedora-post-install}\"" install.sh \
    || fail "installer prefix does not use the Fedora project path"
grep -Fq 'FEDORA_POST_INSTALL_CONFIG' lib/config.bash \
    || fail "shared config loader does not expose the Fedora config override"
grep -Fq "\$HOME/.env-fedora-post-install" lib/config.bash \
    || fail "shared config loader does not use the stable Fedora config path"
grep -Fq "\$HOME/.cache/fedora-setup" setup.sh \
    || fail "setup marker path does not use the Fedora identity"
grep -Fq "\$HOME/fedora-setup.log" setup.sh \
    || fail "setup log path does not use the Fedora identity"

echo "✅ Fedora project identity regression checks passed"
