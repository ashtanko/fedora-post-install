# Migrate this repository from Ubuntu to Fedora

> Historical working brief. The migration described below is complete; keep
> this document as an audit record of the original scope and acceptance
> criteria. Current usage and contributor guidance live in `README.md` and the
> other documents under `docs/`.

You are working in a fork of `ubuntu-post-install` that is being converted into
`fedora-post-install`. Convert it fully: Fedora is the only supported target
when you are done. Do not build a dual-distro abstraction layer and do not keep
`apt` fallbacks — every remaining `apt`/`dpkg`/PPA/snap path is a bug.

## What this repo is

An interactive, idempotent post-install toolkit: ~109 category scripts, a 45-script
`updates/` subsystem, a Go TUI (`cmd/ubuntu-post-install-tui`), a catalog-driven
menu (`config/catalog.txt`), a manifest-driven Docker test harness
(`tests/manifest.sh` + `tests/run-in-docker.sh`), and a release pipeline
(`install.sh`, `Makefile`, `.github/workflows/release.yml`).

Read these before changing anything: `CLAUDE.md`, `AGENT.md`, `.ai/rules.md`,
`docs/CONTRIBUTING.md`, `docs/TESTING.md`, `tests/script-contract-regression.sh`.

Scale of the change, measured: 78 of 109 installer scripts touch `apt`;
32 call `dpkg --print-architecture`; 17 files write `/etc/apt/sources.list.d/`;
5 use `snap`; 1 uses a PPA; 8 download `.deb` files.

## Non-negotiable conventions (they survive the migration unchanged)

Every ported script keeps the existing contract:

- `#!/bin/bash` + `set -euo pipefail` + the bash re-exec shim.
- Sources `lib/config.bash` and calls `load_config "$REPO_ROOT"`.
- Idempotent: detects an existing install and exits 0 early.
- `trap 'rm -f "$TMP"' EXIT` for temp files.
- Shell rc additions written to `~/.zshrc` and `~/.bashrc` behind a `grep -q` guard.
- Emoji legend: 🚀 start · 📦 installing · ✅ success · ❌ error · ⚠️ warning · 💡 tip · 🔧 configuring · 🔍 detecting.
- **Never** pipe a network fetch into a shell. Fetch to a file, verify the digest
  where upstream publishes one, then run it. See `tools/just.sh`.
- GitHub release tags come from `latest_github_tag` in `lib/github.bash`, never
  `api.github.com`.
- Network fetches use `curl --retry 3 --retry-all-errors`.
- No script ends on a bare `[[ cond ]] && cmd` — use an `if` block.
- Repo GPG keys are verified by fingerprint, not merely imported.

`tests/script-contract-regression.sh` enforces several of these against every
script including the ~30 that Docker never runs. Keep it enforcing, and update
its apt-specific rule (see Phase 5).

## Phase 0 — Branch and inventory

1. Work on `feat/fedora-migration`. Commit in phases, not one blob.
2. Produce `docs/FEDORA-MIGRATION.md` with a table of every script and its
   disposition: `port` (mechanism changes), `neutral` (no distro-specific code),
   `replace` (different upstream mechanism on Fedora), `delete` (Ubuntu-only).
   Keep it updated as you go; it is the migration's progress ledger.

Known `delete` candidates — confirm before removing:
- `essentials/motd-news.sh` — Ubuntu ESM/livepatch banner ads do not exist on Fedora.
- `essentials/auto-updates.sh` — not deleted, but fully rewritten (see below).

## Phase 1 — Shared package layer

Add `lib/pkg.bash` (sourced like `lib/github.bash`) so 78 scripts stop
open-coding dnf details:

- `dnf_install pkg...` — `sudo dnf install -y --setopt=install_weak_deps=False`,
  quiet, idempotent.
- `dnf_installed pkg` — `rpm -q` check for early exit.
- `dnf_group_install name` — group syntax differs between dnf4 and dnf5.
- `repo_add name url gpgkey fingerprint` — writes `/etc/yum.repos.d/<name>.repo`
  with `enabled=1 gpgcheck=1 repo_gpgcheck=1`, imports the key **after**
  verifying its fingerprint against a pinned value, and is idempotent.
- `copr_enable owner/project` — ensures `dnf-plugins-core`, then `dnf copr enable -y`.
- `flatpak_install app-id` — ensures Flathub remote is configured (user-level).
- `release_arch` / `rpm_arch` — see the arch trap below.
- `dnf_major` — detects dnf4 vs dnf5 so callers can branch on syntax.

### Traps to handle in this layer, deliberately

- **dnf5.** Fedora 41+ ships dnf5, where `dnf config-manager --add-repo` became
  `dnf config-manager addrepo --from-repofile=…` and group commands changed.
  Detect and branch; do not assume either dialect.
- **Architecture naming.** `dpkg --print-architecture` returns `amd64`/`arm64`;
  `rpm --eval '%{_arch}'` returns `x86_64`/`aarch64`. GitHub release assets are
  usually named with the *Debian* spelling. So you need both: `release_arch`
  (amd64/arm64, for asset URLs) and `rpm_arch` (x86_64/aarch64, for repo URLs).
  Getting this wrong silently downloads the wrong binary — audit all 32 sites.
- **SELinux is enforcing.** Anything writing to `/etc`, installing a systemd
  unit, or placing a binary somewhere unusual may need `restorecon`. Rootless
  containers, `keyd`, and custom unit files are the likely trouble spots.
- **`sudo` group does not exist** — Fedora uses `wheel`. Also `plugdev` does not
  exist on Fedora. Fix `system/user-groups.sh` and `EXTRA_USER_GROUPS`'s default.

## Phase 2 — Identity rename

Rename the project consistently. Every one of these appears in code *and* tests:

| From | To |
|---|---|
| `cmd/ubuntu-post-install-tui/` | `cmd/fedora-post-install-tui/` (plus `go.mod` module path) |
| `bin/ubuntu-post-install-tui-{amd64,arm64}` | `bin/fedora-post-install-tui-…` |
| `~/.cache/ubuntu-setup/` markers | `~/.cache/fedora-setup/` |
| `~/ubuntu-setup.log` (`SETUP_LOG_FILE` default) | `~/fedora-setup.log` |
| `UBUNTU_POST_INSTALL_CONFIG` env var | `FEDORA_POST_INSTALL_CONFIG` |
| `~/.env-ubuntu-post-install` | `~/.env-fedora-post-install` |
| `ubuntu-post-install` CLI symlink + tarball name | `fedora-post-install` |
| `REPO` default in `install.sh` | the new GitHub repo slug |
| `PREFIX` default `~/.local/share/ubuntu-post-install` | `…/fedora-post-install` |
| header text "Ubuntu Dev Environment Setup" in `setup.sh` | Fedora wording |

Touch points: `setup.sh`, `install.sh`, `Makefile`, `lib/config.bash`,
`go.mod`, the TUI source and its test, `.github/workflows/*`, all of `docs/`,
`README.md`, `CLAUDE.md`, `AGENT.md`, `.env.example`, and the tests that assert
these strings (`tests/config-regression.sh`, `tests/installer-regression.sh`,
`tests/tui-launcher-regression.sh`, `tests/release-artifact.sh`).

Do not silently break an existing install: `install.sh` refusing to overwrite an
unmanaged symlink must keep working under the new name.

## Phase 3 — Port the scripts

Work category by category, committing per category. `neutral` scripts (rustup,
nvm, pyenv, rbenv, tarball and GitHub-release installers, `ai/*` npm/pipx tools)
still need an audit for `dpkg --print-architecture`, `apt` prerequisites, and
Debian-only build-dep names — being "neutral" is a claim to verify, not assume.

### The substitutions that are not mechanical

| Script(s) | Ubuntu mechanism | Fedora replacement |
|---|---|---|
| `essentials/firewall.sh` | UFW | firewalld (already installed and enabled by default) — rewrite around zones/services, keep the `ENABLE_UFW`-equivalent opt-out but rename the variable |
| `essentials/auto-updates.sh` | unattended-upgrades | `dnf-automatic` + `dnf-automatic.timer`, `apply_updates=yes` for security only |
| `essentials/swap.sh` | plain swapfile | Fedora enables **zram** by default (`zram-generator`). Decide and document whether to add a disk swapfile at all; on **btrfs** (Fedora's default root fs) a swapfile requires `btrfs filesystem mkswapfile` or `chattr +C` on an empty file — a plain `fallocate` swapfile fails |
| `essentials/fstrim.sh`, `essentials/journald.sh` | enable timer / cap journal | `fstrim.timer` is already enabled on Fedora; make the script detect and no-op cleanly rather than claiming it configured something |
| `essentials/fail2ban.sh` | apt + jail.d | Fedora package plus `fail2ban-firewalld`; the sshd jail needs the systemd backend |
| `system/base.sh` | `apt upgrade` + `build-essential` | `dnf upgrade --refresh` + `@development-tools` group (`dnf group install development-tools`) — note `build-essential` also appears in `dev/cpp.sh`, `dev/python.sh`, `dev/ruby.sh`, `ai/llama-cpp.sh`, `software/vmware.sh` |
| `system/user-groups.sh` | `sudo`, `plugdev` | `wheel`; drop `plugdev`; keep `dialout`, `docker`, `wireshark` |
| `system/keyboard.sh` | keyd via apt | keyd is packaged for Fedora — verify it is in the main repos at migration time, otherwise COPR. SELinux + `/dev/uinput` need checking |
| `dev/php.sh` | `ondrej/php` PPA + suite probing | Remi's repository (or Fedora's own PHP, which is current). Delete the entire Launchpad suite-probing logic and `UBUNTU_CODENAME` handling |
| `dev/dotnet.sh` | Microsoft apt repo | Fedora ships `dotnet-sdk-*` natively; prefer that over the Microsoft repo |
| `dev/databases.sh` | apt clients | Fedora replaced `redis` with **valkey** in recent releases — resolve which the target release ships and adapt the `redis-cli` verification in `tests/manifest.sh` |
| `dev/docker.sh` | docker.com apt repo + Desktop `.deb` | docker.com's Fedora yum repo + the Desktop `.rpm`; Fedora ships podman by default, so document/handle the coexistence |
| `dev/java.sh` | `update-alternatives` | Fedora's `alternatives` and `java-*-openjdk-devel` package naming |
| `dev/kubernetes.sh`, `dev/terraform.sh`, `dev/gcloud.sh`, `dev/aws-cli.sh`, `tools/trivy.sh` | apt repos | each upstream publishes an equivalent yum repo — use `repo_add` with a pinned key fingerprint |
| `tools/cli-tools.sh`, `tools/modern-cli.sh` | `batcat`/`fdfind` symlink workarounds | **Delete them.** Fedora's `bat` and `fd-find` packages install `/usr/bin/bat` and `/usr/bin/fd` under the correct names. Also update `tests/verify/tools_cli-tools.sh` and `tests/verify/tools_modern-cli.sh`, which currently assert the Debian names |
| `tools/system-maintenance.sh` | `apt autoremove`, snap prune | `dnf autoremove`, `dnf clean all`, keep journal vacuum and flatpak prune, drop snap entirely |
| `ide/android-studio.sh` | snap `--classic` | official tarball or the Flathub app; update `updates/update-android-studio.sh` in lockstep |
| `ide/dbeaver.sh`, `apps/warp.sh`, `apps/vscode.sh`, `apps/browsers.sh` | apt repos / `.deb` | each vendor publishes an RPM repo (`packages.microsoft.com/yumrepos/vscode`, Google Chrome's yum repo, Warp's RPM repo) |
| `ide/cursor.sh` | AppImage | AppImage still works but needs `fuse` on Fedora — install the dependency or extract instead |
| `software/virtualbox.sh` | apt + extension pack | Oracle's Fedora repo or RPM Fusion, plus `kernel-devel`, `akmods`, and a **Secure Boot MOK enrollment** path that must be explained, not silently skipped |
| `software/vmware.sh` | build prereqs | `kernel-devel`, `kernel-headers`, `gcc`, `make`, `perl`, `elfutils-libelf-devel` |
| `vpn/nord.sh`, `vpn/tailscale.sh` | apt installers | both ship Fedora repos; Tailscale's is a `.repo` file |
| `ai/claude.sh`, `ai/antigravity.sh`, `ai/gemini.sh`, `ai/cline.sh`, `ai/mcp-inspector.sh` | apt repos / NodeSource apt | check for an RPM channel first; fall back to each tool's official standalone installer. NodeSource publishes RPM repos |
| `tools/wireshark.sh` | debconf preseed for non-root capture | there is no debconf — use the `wireshark` group plus `setcap` on `dumpcap` |

Anything a Fedora repo already provides should come from the Fedora repo rather
than a vendor repo, unless the Fedora package is materially out of date. Say
which you chose and why in a comment where it is not obvious.

## Phase 4 — `updates/` subsystem

`updates/` mirrors the installers, so every mechanism change above has a partner
here. Re-audit `updates/catalog.txt` and `updates/skipped.txt`: a tool whose
Fedora install path is a dnf repo now self-updates through `dnf upgrade` and may
belong in `skipped.txt` with that reason recorded. `updates/update-all.sh` and
`tests/update-scripts-regression.sh` (20 apt references — the highest count in
the repo) must both be updated.

## Phase 5 — Tests and CI

1. `tests/Dockerfile`: base on `fedora:<version>` with a `FEDORA_VERSION` build
   arg. Replace the apt bootstrap with `dnf -y install` of the equivalents
   (`sudo`, `curl`, `wget`, `ca-certificates`, `gnupg2`, `git`, `file`,
   `procps-ng`, `findutils`, `@development-tools`, `glibc-langpack-en`). The
   test user joins `wheel`, not `sudo`. Note `dnf` in the official image is dnf5.
2. `tests/run-in-docker.sh` and the `Makefile`: `UBUNTU=` → `FEDORA=`, and the
   version whitelist becomes the currently supported Fedora releases. **Verify
   which releases are current when you run this** (check the Fedora release
   schedule) rather than trusting a number written into this prompt.
3. `.github/workflows/docker-tests.yml`, `release.yml`, `nightly-health.yml`:
   swap the matrix and the job names. Runners stay `ubuntu-latest` — that is
   GitHub's host OS, not our target, and should not be renamed.
4. `tests/manifest.sh`: many `compat=no` skip reasons cite Debian specifics, and
   several `verify` commands use `dpkg -s` (e.g. `system/ntp.sh` asserts chrony
   via `dpkg -s`). Rewrite verifications to `rpm -q` and rewrite skip reasons to
   state the real Fedora limitation. Re-evaluate each `compat` flag: some
   scripts that were untestable on Ubuntu may be testable on Fedora, and vice versa.
5. `tests/script-contract-regression.sh`: rule 3 ("apt-get install must be
   preceded by apt-get update") is obsolete — `dnf` refreshes metadata itself.
   Replace it with Fedora-relevant contracts:
   - no `apt`, `apt-get`, `dpkg`, `add-apt-repository`, `snap`, or `.deb`
     anywhere in the tree (this is the migration's own regression guard);
   - every `/etc/yum.repos.d/*.repo` written by a script sets `gpgcheck=1`;
   - no script hardcodes `x86_64` or `amd64` where `release_arch`/`rpm_arch` belongs.
   Keep rules 1, 2, and 4 intact.
6. `make check` (lint + manifest + regressions + tui-test) must pass, and
   `bash tests/catalog-regression.sh` must pass per `.ai/rules.md`.
7. Run the full smoke and idempotency stages on at least one Fedora version
   locally and report the real results — including anything still failing.

## Phase 6 — Documentation

Update `README.md`, all of `docs/`, `CLAUDE.md`, `AGENT.md`, `.ai/rules.md`, and
`.env.example` to describe Fedora. This is not a find-and-replace of the word
"Ubuntu": the script inventory tables, the config variable table, the testing
instructions, and the troubleshooting guide all contain distro-specific claims
that are now wrong. `docs/TROUBLESHOOTING.md` and `docs/SECURITY.md` need real
Fedora content (SELinux denials, firewalld, RPM key trust, Secure Boot).

Rename any config variables whose names encode the distro, and document the
rename for existing users.

## Definition of done

- `grep -rniE '\bapt(-get)?\b|dpkg|\.deb\b|ppa:|/etc/apt|snap install|unattended-upgrades|\bufw\b'`
  over the tree returns only intentional historical references (e.g. the
  migration doc), and the contract test enforces that.
- `make check` passes.
- Smoke + idempotency stages pass on the supported Fedora matrix, or every
  remaining failure is listed with its cause.
- `config/catalog.txt`, `tests/manifest.sh`, and `docs/SCRIPTS.md` agree with
  the scripts that actually exist (per `.ai/rules.md`).
- `make release-dry-run` produces a verifiable `fedora-post-install-<v>.tar.gz`.
- `docs/FEDORA-MIGRATION.md` records the disposition of every script and every
  non-obvious upstream choice.

## Working agreement

- Do not delete a script because porting it is hard. If a tool genuinely has no
  Fedora path, mark it `delete`, remove it from the catalog and manifest, and
  say so explicitly in the migration doc and in your final report.
- Do not invent repo URLs, package names, or GPG fingerprints from memory —
  verify each against upstream documentation before pinning it. A wrong pinned
  fingerprint fails closed, which is correct, but a wrong repo URL that happens
  to resolve is a supply-chain problem.
- Report honestly: if a stage fails or a script is untested, say so plainly with
  the output rather than describing the migration as complete.
- Ask before: changing the git remote, force-pushing, deleting the `updates/`
  subsystem wholesale, or dropping a whole category.
