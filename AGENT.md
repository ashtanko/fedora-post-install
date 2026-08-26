# Agent project context: fedora-post-install

This repository contains automated, repeat-safe Bash scripts for provisioning
Fedora Workstation 43 and 44. The full-screen terminal installer and classic
Bash fallback both use `config/catalog.txt`; every installer can also run
standalone.

## Project overview

- **Target:** Fedora Workstation only. Debian/Ubuntu package paths are migration
  regressions, not fallbacks.
- **Architecture:** independent scripts grouped under `essentials/`, `system/`,
  `apps/`, `dev/`, `tools/`, `ide/`, `ai/`, `software/`, `vpn/`, and the manual
  `mobile/` directory. Maintenance wrappers live under `updates/`.
- **Entry points:** `fedora-post-install` for release installs, `bash setup.sh`
  from source, or `bash <category>/<script>.sh` for one component.
- **Configuration:** `lib/config.bash` loads inherited environment variables,
  then repo `.env`, then `~/.env-fedora-post-install`. The path can be changed
  through `FEDORA_POST_INSTALL_CONFIG`.
- **State:** successful menu runs create markers in
  `~/.cache/fedora-setup/`; output is appended to `~/fedora-setup.log` by
  default.

## Building and validation

```bash
bash setup.sh
make tui-build
make check
bash tests/run-in-docker.sh 44 smoke
bash tests/run-in-docker.sh 44 idempotency
make release-dry-run
```

The supported Docker matrix is Fedora 43 and 44, with Fedora 44 as the local
default. `tests/manifest.sh` is the test inventory; `config/catalog.txt` is the
installer inventory; `updates/catalog.txt` plus `updates/skipped.txt` record
update ownership.

## Development conventions

- Start scripts with `#!/bin/bash`, `set -euo pipefail`, and the Bash re-exec
  shim used by neighboring scripts.
- Load settings through `lib/config.bash`. Use `lib/pkg.bash` for Fedora
  packages, groups, architectures, COPRs, Flatpak, and third-party repositories.
- Use `dnf_install`/`dnf_group_install` for Fedora packages. Add third-party RPM
  repositories only through `repo_add`, with an exact vendor-published primary
  fingerprint and package signature checking enabled.
- Use `release_arch` for upstream assets and `rpm_arch` for RPM repository
  paths. Do not add ad-hoc `uname -m` probes.
- Download installers to a temporary file instead of piping a network response
  into a shell. Verify the vendor digest or signature when one is published.
- Preserve idempotency. Guard rc-file edits with `grep -q`, clean temporary
  files with traps, and never end a script with a bare conditional command.
- Restore SELinux contexts after writing system files where neighboring scripts
  do so. Do not disable SELinux to make an installer pass.
- Use the existing output legend: 🚀 start · 📦 install · ✅ success · ❌ error
  · ⚠️ warning · 💡 tip · 🔧 configure · 🔍 detect.

## Adding or changing an installer

1. Update `config/catalog.txt` when the selectable inventory changes.
2. Update `tests/manifest.sh` and add a verifier under `tests/verify/` when a
   one-line assertion is insufficient.
3. Add updater ownership to `updates/catalog.txt`, or an audited omission to
   `updates/skipped.txt`.
4. Keep `docs/SCRIPTS.md`, `docs/CONFIG.md`, and `.env.example` synchronized.
5. Run `bash tests/catalog-regression.sh` and `make check`; run targeted Fedora
   smoke/idempotency tests when the script is container-compatible.

See `CLAUDE.md` for the detailed script inventory and `docs/CONTRIBUTING.md` for
the complete contributor workflow.
