#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    echo "❌ $*" >&2
    exit 1
}

HOME_DIR="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

cat > "$FAKE_BIN/bash" <<'EOF'
#!/bin/bash
case "${1:-}" in
    */essentials/system-info.sh)
        echo "stub system info"
        exit 0
        ;;
    */essentials/swap.sh)
        echo "stub swap failure" >&2
        exit 1
        ;;
    *) exec /bin/bash "$@" ;;
esac
EOF
chmod +x "$FAKE_BIN/bash"

HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" SETUP_LOG_FILE="$TEST_ROOT/setup.log" \
    /bin/bash "$REPO_ROOT/setup.sh" --run-item essentials/system-info.sh >/dev/null
[ -f "$HOME_DIR/.cache/fedora-setup/essentials_system-info.sh.done" ] \
    || fail "successful TUI runner item did not create its marker"

# A completed item must skip without invoking the now-failing child stub.
cat > "$FAKE_BIN/bash" <<'EOF'
#!/bin/bash
case "${1:-}" in
    */essentials/system-info.sh) exit 99 ;;
    */essentials/swap.sh) exit 1 ;;
    */essentials/lynis.sh) exit 78 ;;
    *) exec /bin/bash "$@" ;;
esac
EOF
chmod +x "$FAKE_BIN/bash"
HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" SETUP_LOG_FILE="$TEST_ROOT/setup.log" \
    /bin/bash "$REPO_ROOT/setup.sh" --run-item essentials/system-info.sh >/dev/null

set +e
HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" SETUP_LOG_FILE="$TEST_ROOT/setup.log" \
    /bin/bash "$REPO_ROOT/setup.sh" --run-item essentials/swap.sh >/dev/null 2>&1
failure_status=$?
HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" SETUP_LOG_FILE="$TEST_ROOT/setup.log" \
    /bin/bash "$REPO_ROOT/setup.sh" --run-item does/not-exist.sh >/dev/null 2>&1
unknown_status=$?
# A step the host cannot run (an atomic image that cannot layer RPMs) reports
# the reserved skip status rather than a failure.
HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" SETUP_LOG_FILE="$TEST_ROOT/setup.log" \
    /bin/bash "$REPO_ROOT/setup.sh" --run-item essentials/lynis.sh >/dev/null 2>&1
unsupported_status=$?
set -e

[ "$failure_status" -eq 1 ] || fail "failed TUI runner item returned $failure_status instead of 1"
[ ! -f "$HOME_DIR/.cache/fedora-setup/essentials_swap.sh.done" ] \
    || fail "failed TUI runner item created a completion marker"
[ "$unknown_status" -eq 2 ] || fail "unknown TUI runner item returned $unknown_status instead of 2"
[ "$unsupported_status" -eq 78 ] \
    || fail "unsupported-host item returned $unsupported_status instead of 78"
# No marker, so the step runs again when the repo is used on a mutable host.
[ ! -f "$HOME_DIR/.cache/fedora-setup/essentials_lynis.sh.done" ] \
    || fail "unsupported-host item created a completion marker"
grep -q 'skipped' "$TEST_ROOT/setup.log" \
    || fail "unsupported-host item was not reported as a skip in the log"
grep -q 'Lynis.*FAILED' "$TEST_ROOT/setup.log" \
    && fail "unsupported-host item was reported as a failure"

echo "✅ TUI launcher validates catalog items, failures, skips, and markers"
