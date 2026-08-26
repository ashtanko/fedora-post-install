#!/bin/bash
# Static contract checks that run against EVERY installable script — including
# the ~30 marked `compat=no` in tests/manifest.sh, which no Docker stage ever
# executes. Those scripts are the blind spot where runtime bugs survive, so the
# classes that are cheaply detectable without running anything are caught here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0
report() {
    echo "❌ $*" >&2
    ((++failures))
}

mapfile -t scripts < <(find ai apps dev essentials ide mobile software system tools updates vpn \
    -maxdepth 1 -type f -name '*.sh' | sort)
scripts+=(setup.sh install.sh)

# Strip comments and blank lines; what remains is what bash actually runs.
effective_lines() {
    grep -vE '^[[:space:]]*(#|$)' "$1"
}

for script in "${scripts[@]}"; do
    # 1. It has to parse. `bash -n` is the only check that reaches a compat=no
    #    script's syntax at all today.
    bash -n "$script" 2>/dev/null || report "$script: does not parse under bash -n"

    # 2. The final command must not be a bare conditional. `[[ cond ]] && echo …`
    #    as the last line makes the script exit 1 whenever the condition is
    #    false, so setup.sh reports a successful run as FAILED and writes no
    #    completion marker. Regression guard for tools/backup-home.sh.
    last="$(effective_lines "$script" | tail -1)"
    if [[ "$last" =~ ^[[:space:]]*(\[\[|\[|test[[:space:]]) ]] && [[ "$last" != *exit* ]]; then
        report "$script: ends in a bare conditional, so it exits non-zero when that condition is false:
    $last"
    fi

    # 3. Fedora is the only supported target. Production scripts must not keep
    #    Debian package commands/assets, and architecture-sensitive paths must
    #    use the shared RPM/release mappings instead of probing the host again.
    effective="$(effective_lines "$script")"
    if grep -Eq '(^|[^[:alnum:]_])(apt|apt-get|apt-cache|dpkg|dpkg-query|add-apt-repository|snap)([^[:alnum:]_-]|$)|\.deb([^[:alnum:]_]|$)|/etc/apt' \
        <<< "$effective"; then
        report "$script: retains a Debian/Ubuntu package path"
    fi
    if grep -Eq 'uname[[:space:]]+-m|dpkg[[:space:]]+--print-architecture' \
        <<< "$effective"; then
        report "$script: probes architecture outside the shared Fedora helpers"
    fi
    if grep -Eq '\b(x86_64|amd64|aarch64|arm64)\b' <<< "$effective" \
        && ! grep -Eq '\b(rpm_arch|release_arch)\b' <<< "$effective"; then
        report "$script: contains architecture-specific behavior without rpm_arch/release_arch"
    fi
    if grep -Eq '(^|[[:space:]])repo_add[[:space:]]' <<< "$effective" \
        && ! grep -Fq "source \"\$PKG_HELPER\"" <<< "$effective"; then
        report "$script: configures an RPM repository without the shared signed-repository helper"
    fi

    # 4. No piping a network fetch into a shell. Every such install must land in
    #    a file first (so a truncated transfer cannot half-execute) and, where
    #    upstream publishes one, be checksum-verified. Lines that merely *print*
    #    an upstream one-liner as a hint are commands starting with echo, so the
    #    anchored match skips them.
    if effective_lines "$script" \
        | grep -qE '^[[:space:]]*(curl|wget)[^|]*\|[[:space:]]*(sudo +)?(ba)?sh\b'; then
        report "$script: pipes a network fetch directly into a shell"
    fi
done

# All project-written repository files flow through repo_add. Keep package
# signature checking mandatory even when a vendor cannot sign repository
# metadata and requires the narrowly scoped repo_gpgcheck=0 exception.
if ! effective_lines lib/pkg.bash | grep -Fq 'gpgcheck=1'; then
    report "lib/pkg.bash: repo_add does not require gpgcheck=1"
fi

if (( failures > 0 )); then
    echo "" >&2
    echo "❌ $failures script contract violation(s)" >&2
    exit 1
fi

echo "✅ script contracts OK (${#scripts[@]} scripts)"
