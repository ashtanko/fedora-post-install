# Fedora migration ledger

This file tracks the conversion from `ubuntu-post-install` to
`fedora-post-install`. Fedora is the only intended target. A `neutral`
classification means the current mechanism appears distribution-independent;
it does **not** mean the Fedora audit or runtime validation is complete.

## Progress

| Phase | State | Notes |
|---|---|---|
| 0 — branch and inventory | Complete | `feat/fedora-migration` created; all 110 original installer/manual scripts and 44 updater scripts were inventoried; one confirmed Ubuntu-only script has since been removed |
| 1 — shared package layer | Complete | `lib/pkg.bash` provides DNF4/DNF5, repository, COPR, Flatpak, and architecture helpers with isolated regression coverage |
| 2 — identity rename | Complete | Runtime paths, configuration, TUI/module, CLI, release artifacts, workflows, tests, and documentation use the Fedora identity |
| 3 — installer ports | Complete | All ten installer/manual-script categories are ported and audited for Fedora |
| 4 — updater ports | Complete | All 37 retained updaters are audited; RPM-owned tools use targeted DNF updates, while standalone and source-owned tools verify provenance before native or verified replacement updates |
| 5 — Fedora tests and CI | Complete | Fedora 43/44 DNF5 containers, workflow matrices, RPM state snapshots, and Fedora script contracts are active; Fedora 44 full smoke and idempotency pass all 77 runnable entries, and Fedora 43 passes a representative package smoke test |
| 6 — documentation | Complete | User, contributor, agent, configuration, testing, release, security, and troubleshooting guidance now describes Fedora 43/44, DNF/RPM trust, firewalld, SELinux, and Secure Boot; local checks and an isolated release dry-run pass |

## Dispositions

- `port`: keep the script and behavior, but translate distro-specific packages,
  architecture detection, repository setup, groups, or SELinux handling.
- `neutral`: retain the current upstream mechanism after a Fedora dependency and
  architecture audit.
- `replace`: keep the user-facing capability but implement it through a
  materially different Fedora mechanism.
- `delete`: remove an Ubuntu-only capability after synchronizing the catalog,
  manifest, update coverage, and documentation.

Status is intentionally conservative: no installer below is marked complete
until its implementation and tests have moved to Fedora.

## Installer and manual-script inventory

### `ai/`

| Script | Disposition | Status / reason |
|---|---|---|
| `ai/aider.sh` | neutral | Complete; retains the official user-local installer after Fedora audit |
| `ai/antigravity.sh` | replace | Complete; uses Google's Artifact Registry RPM channel with the Google Linux package-key fingerprint pinned and package signature checking enabled |
| `ai/claude.sh` | replace | Complete; uses Anthropic's signed Fedora-compatible RPM channel with the published key fingerprint pinned |
| `ai/cline.sh` | port | Complete; uses a shared Node.js runtime selector with a signed NodeSource RPM fallback |
| `ai/codex.sh` | neutral | Complete; retains the official user-local standalone installer after Fedora audit |
| `ai/cursor-agent.sh` | neutral | Complete; retains the official user-local upstream installer after Fedora audit |
| `ai/fabric.sh` | neutral | Complete; retains its user-local upstream installation after Fedora audit |
| `ai/gemini.sh` | port | Complete; uses a shared Node.js runtime selector with a signed NodeSource RPM fallback |
| `ai/github-copilot.sh` | neutral | Complete; retains the official user-local upstream installer after Fedora audit |
| `ai/goose.sh` | neutral | Complete; retains the official user-local upstream installer after Fedora audit |
| `ai/huggingface-cli.sh` | port | Complete; installs missing Fedora `curl`/`python3` prerequisites before the saved official installer |
| `ai/litellm.sh` | port | Complete; installs Fedora's `python3` and `pipx` packages when pipx is absent |
| `ai/llama-cpp.sh` | port | Complete; uses Fedora's development-tools group and native CMake, pkg-config, ccache, and libcurl development packages |
| `ai/llm-cli.sh` | port | Complete; installs Fedora's `python3` and `pipx` packages when pipx is absent |
| `ai/mcp-inspector.sh` | port | Complete; uses a shared Node.js runtime selector with a signed NodeSource RPM fallback |
| `ai/mistral-vibe.sh` | neutral | Complete; retains the official user-local Python installer after Fedora audit |
| `ai/ollama-models.sh` | neutral | Complete; remains a distribution-neutral client of an existing Ollama service |
| `ai/ollama.sh` | port | Complete; validates RPM architecture before the official installer, supplies Fedora prerequisites, restores SELinux contexts, and manages the systemd unit when available |
| `ai/opencode.sh` | neutral | Complete; retains the official user-local upstream installer after Fedora audit |
| `ai/prompt-runner.sh` | port | Complete; installs missing Fedora `curl` and `jq` packages before writing the local wrapper |
| `ai/qwen-code.sh` | neutral | Complete; retains the official user-local standalone installer after Fedora audit |

### `apps/`

| Script | Disposition | Status / reason |
|---|---|---|
| `apps/bitwarden-cli.sh` | port | Complete; uses Fedora archive prerequisites and rejects non-x86_64 hosts before package changes because the vendor native build remains x86-only |
| `apps/browsers.sh` | port | Complete; uses Google's x86_64 RPM repository with the exact published primary-key fingerprint |
| `apps/flameshot.sh` | port | Complete; installs Fedora's `flameshot` package through the shared DNF helper |
| `apps/guake.sh` | port | Complete; installs Fedora's `guake` package through the shared DNF helper |
| `apps/postman.sh` | port | Complete; maps RPM architecture to both official Linux archives and activates a validated extraction transactionally without replacing an unknown path |
| `apps/vscode.sh` | port | Complete; uses Microsoft's VS Code yum repository with the exact published primary-key fingerprint |
| `apps/warp.sh` | port | Complete; uses Warp's signed RPM channel, which currently publishes both x86_64 and aarch64 packages |

### `dev/`

| Script | Disposition | Status / reason |
|---|---|---|
| `dev/aws-cli.sh` | port | Complete; verifies AWS CLI and Session Manager detached signatures against embedded, fingerprint-pinned vendor keys and selects RPM architecture |
| `dev/azure-cli.sh` | port | Complete; uses Microsoft's signed EL9 RPM channel through the shared repository helper |
| `dev/bun.sh` | port | Complete; retains the user-local upstream installer with Fedora-managed prerequisites |
| `dev/cpp.sh` | port | Complete; uses Fedora's development-tools group and native compiler, debugger, formatter, analyzer, and profiler packages |
| `dev/databases.sh` | replace | Complete; uses Fedora PostgreSQL/MariaDB/SQLite/Valkey clients, MongoDB's signed EL9 RPM channel, and pipx interactive shells |
| `dev/deno.sh` | port | Complete; retains the user-local upstream installer with Fedora-managed prerequisites |
| `dev/docker-rootless.sh` | port | Complete; installs Fedora rootless networking/storage and SELinux dependencies while retaining explicit subuid/subgid and user-session checks |
| `dev/docker.sh` | port | Complete; uses Docker's signed Fedora RPM channel, starts the systemd service when available, detects `podman-docker` conflicts, and limits Desktop to x86_64 |
| `dev/dotnet.sh` | replace | Complete; uses Fedora's native `dotnet-sdk-*` packages and verifies the requested SDK major.minor |
| `dev/flutter.sh` | port | Complete; translates the Linux desktop toolchain and runtime libraries to Fedora packages while leaving Android SDK setup separate |
| `dev/gcloud.sh` | port | Complete; uses Google's architecture-specific EL9 RPM channel with a pinned package-key fingerprint and documented metadata-check exception |
| `dev/go.sh` | port | Complete; retains checksum-verified upstream archives and uses shared RPM/release architecture mapping in both installer and updater |
| `dev/java.sh` | replace | Complete; installs `java-*-openjdk-devel` through DNF and documents Fedora's `alternatives` command |
| `dev/kubernetes.sh` | port | Complete; installs kubectl from the signed v1.36 RPM channel and uses shared release architecture for checksum-verified companion tools |
| `dev/node.sh` | neutral | Complete; NVM remains user-local, with curl and git prerequisites owned by DNF |
| `dev/php.sh` | replace | Complete; uses Fedora-native PHP and extensions; `PHP_VERSION` is an assertion rather than a third-party repository selector |
| `dev/podman.sh` | port | Complete; uses Fedora Podman, podman-compose, rootless, and SELinux packages with explicit subuid/subgid reporting |
| `dev/python.sh` | port | Complete; uses Fedora's development-tools group and pyenv build dependencies while retaining user-local pyenv/Poetry ownership |
| `dev/ruby.sh` | port | Complete; uses Fedora's development-tools group and ruby-build dependencies while retaining user-local rbenv ownership |
| `dev/rust.sh` | neutral | Complete; rustup remains user-local and curl is supplied through DNF |
| `dev/terraform.sh` | port | Complete; uses HashiCorp's signed Fedora RPM channel, retains checksum-verified tflint, and verifies tfsec's detached signature |

### `essentials/`

| Script | Disposition | Status / reason |
|---|---|---|
| `essentials/auto-updates.sh` | replace | Complete; uses `dnf5-plugin-automatic`/`dnf5-automatic.timer`, with a DNF4 compatibility path, security-only application, and no automatic reboot |
| `essentials/fail2ban.sh` | replace | Complete; installs `fail2ban-firewalld` and configures the sshd jail with the systemd backend |
| `essentials/firewall.sh` | replace | Complete; enables firewalld, preserves the selected zone policy, and ensures its SSH service is allowed |
| `essentials/fstrim.sh` | replace | Complete; uses Fedora's `util-linux` package when needed and no-ops when the timer is already enabled |
| `essentials/gnome-settings.sh` | neutral | Complete; GNOME `gsettings` behavior and session guards are distribution-independent |
| `essentials/journald.sh` | port | Complete; retains the journal cap and restores the SELinux label on its drop-in |
| `essentials/locale-timezone.sh` | port | Complete; installs Fedora `glibc-langpack-*`, uses `/etc/locale.conf`, and retains systemd locale/timezone management |
| `essentials/lynis.sh` | port | Complete; installs Fedora's `lynis` package through the shared DNF helper |
| `essentials/motd-news.sh` | delete | Complete; removed because Fedora has no Ubuntu motd-news/ESM advertising facility |
| `essentials/swap.sh` | replace | Complete; respects active zram, defaults disk swap off, and uses Btrfs-native swapfile creation when opted in |
| `essentials/sysctl-limits.sh` | neutral | Complete; standard drop-ins retained and relabeled for SELinux before application |
| `essentials/system-info.sh` | neutral | Complete; read-only system inventory has no distro-specific mutation or package dependency |

### `ide/`

| Script | Disposition | Status / reason |
|---|---|---|
| `ide/android-studio.sh` | replace | Complete; replaces Snap with Google's x86_64 tarball, resolves its current URL and SHA-256 from the official page, and activates validated archives transactionally |
| `ide/cursor.sh` | replace | Complete; Cursor now publishes a signed x86_64/aarch64 RPM repository, whose current key fingerprint and signed metadata are pinned instead of retaining the old AppImage |
| `ide/dbeaver.sh` | replace | Complete; DBeaver's documented RPM is a standalone download and the claimed RPM repository URLs return 404, so the script uses the Flathub app listed on DBeaver's official download page |
| `ide/jetbrains-toolbox.sh` | port | Complete; maps x86_64/aarch64 release metadata, verifies JetBrains' published SHA-256, and installs the documented Fedora runtime packages without obsolete FUSE |
| `ide/nvim.sh` | replace | Complete; Fedora 43 provides Neovim 0.11 and Fedora 44 provides 0.12, so the current signed Fedora package replaces the separately managed release archive |
| `ide/vscode-extensions.sh` | neutral | Complete; operates through the existing RPM-owned VS Code CLI and exits explicitly after reporting extension failures |
| `ide/zed.sh` | port | Complete; retains Zed's official saved preview installer, validates a supported RPM architecture, and installs its curl prerequisite through DNF |

### `mobile/`

| Script | Disposition | Status / reason |
|---|---|---|
| `mobile/zip_flutter_plugin.sh` | port | Complete; installs Fedora's `zip` package through the shared helper, validates source/output paths, and atomically replaces a fresh archive while excluding its own output so deleted files cannot survive from an earlier run |

### `software/`

| Script | Disposition | Status / reason |
|---|---|---|
| `software/boxes.sh` | port | Complete; installs Fedora's virtualization group plus GNOME Boxes, enables libvirt and its default NAT network, and grants the user libvirt access |
| `software/virtualbox.sh` | replace | Complete; uses RPM Fusion Free's x86_64 `VirtualBox` and `akmod-VirtualBox` packages through a fingerprint-pinned repository, builds for the running kernel, stops for required Secure Boot MOK enrollment, and optionally verifies Oracle's published SHA-256 before the PUEL Extension Pack license prompt |
| `software/vmware.sh` | port | Complete; installs the exact running-kernel development package and Fedora compiler, Perl, libelf, signing, and MOK prerequisites, then documents Broadcom's manual bundle and Secure Boot module-signing path |

### `system/`

| Script | Disposition | Status / reason |
|---|---|---|
| `system/base.sh` | port | Complete; refreshes/upgrades through DNF, installs the development-tools group, and uses Fedora workstation package names |
| `system/gpg.sh` | port | Complete; installs Fedora's `gnupg2` package when the `gpg` command is absent |
| `system/hostname.sh` | port | Complete; uses hostnamectl or `/etc/hostname` without adding Debian's `127.0.1.1` hosts entry |
| `system/hosts-dns.sh` | neutral | Complete; configures only an already-active systemd-resolved stack and otherwise preserves NetworkManager DNS |
| `system/keyboard.sh` | port | Complete; uses the maintained `alternateved/keyd` COPR because keyd is absent from Fedora's main repositories, validates `/dev/uinput`, and restores SELinux labels |
| `system/ntp.sh` | port | Complete; installs Fedora's chrony package and enables the `chronyd` service under systemd |
| `system/ssh.sh` | port | Complete; uses Fedora's `openssh-clients` prerequisite and restores labels on the SSH directory |
| `system/sudoers.sh` | neutral | Complete; retains pre-install validation and restores the SELinux label on the installed drop-in |
| `system/user-groups.sh` | port | Complete; defaults to `wheel docker dialout wireshark`, maps `sudo` to `wheel`, and ignores `plugdev` |

### `tools/`

| Script | Disposition | Status / reason |
|---|---|---|
| `tools/atuin.sh` | port | Complete; Fedora 43/44 ship 18.12.1 versus upstream 18.20.0 with later Bash integration fixes, so the materially newer checksum-published release is installed with shared RPM architecture mapping |
| `tools/backup-home.sh` | neutral | Complete; audited as a distribution-neutral user-data archive utility |
| `tools/btop.sh` | port | Complete; installs Fedora's `btop` package through DNF |
| `tools/cli-tools.sh` | port | Complete; uses Fedora packages for the full set and needs no `batcat` compatibility link or GitHub CLI vendor repository |
| `tools/ctop.sh` | port | Complete; retains the checksum-verified release binary and uses shared release architecture mapping |
| `tools/dive.sh` | replace | Complete; installs Dive's checksum-verified official RPM release through DNF |
| `tools/docker-maintenance.sh` | neutral | Complete; audited as Docker CLI maintenance with no distribution package path |
| `tools/dotfiles.sh` | port | Complete; installs Fedora's current `chezmoi` package through DNF and retains optional non-applying repository initialization |
| `tools/fish.sh` | port | Complete; installs Fedora's Fish package, validates `/etc/shells`, and retains Fisher setup |
| `tools/fonts.sh` | port | Complete; installs Fedora archive/fontconfig prerequisites before extracting Nerd Fonts |
| `tools/git-config.sh` | neutral | Complete; audited as distribution-neutral Git configuration |
| `tools/gitleaks.sh` | port | Complete; installs Fedora's current `gitleaks` package through DNF |
| `tools/hadolint.sh` | port | Complete; installs Fedora's current `hadolint` package through DNF |
| `tools/just.sh` | port | Complete; installs Fedora's current `just` package through DNF |
| `tools/lazydocker.sh` | port | Complete; retains the checksum-verified release archive and uses shared architecture mapping |
| `tools/modern-cli.sh` | port | Complete; uses Fedora packages for all but lazygit and needs no `fdfind` compatibility link |
| `tools/network-tools.sh` | port | Complete; maps DNS, socket, and netcat commands to `bind-utils`, `iproute`, and `nmap-ncat` |
| `tools/pre-commit-setup.sh` | port | Complete; installs Fedora's current `pre-commit` package through DNF and retains Git template configuration |
| `tools/rclone.sh` | port | Complete; uses Fedora's current signed `rclone` package and delegates updates to DNF |
| `tools/restic.sh` | port | Complete; uses Fedora's current signed `restic` package and delegates updates to DNF |
| `tools/starship.sh` | port | Complete; replaces the mutable installer with a checksum-verified user-local release archive and shared RPM architecture mapping |
| `tools/system-maintenance.sh` | replace | Complete; uses DNF autoremove/cache cleanup, retains journal/Flatpak/Docker cleanup, and removes Snap handling |
| `tools/tmux-config.sh` | port | Complete; installs Fedora's tmux and Git prerequisites through DNF |
| `tools/trivy.sh` | port | Complete; uses Aqua's RPM repository, pins signing key `825AD9036F7C850E6A6FED4935B8ACA44FD9CA9F`, and documents its unsigned repository metadata |
| `tools/wireshark.sh` | replace | Complete; installs Fedora's GUI/CLI packages and configures the wireshark group plus `dumpcap` capabilities |
| `tools/yq.sh` | port | Complete; installs Fedora's current Mike Farah `yq` package through DNF |
| `tools/zsh.sh` | port | Complete; installs Fedora's Zsh/curl packages and retains the saved Oh My Zsh installer flow |

### `vpn/`

| Script | Disposition | Status / reason |
|---|---|---|
| `vpn/nord.sh` | port | Complete; uses NordVPN's signed x86_64/aarch64 RPM repository, pins key `BC5480EFEC5C081CE5BCFBE26B219E535C964CA1`, enables `nordvpnd`, and retains non-root group setup |
| `vpn/tailscale.sh` | port | Complete; reproduces Tailscale's signed Fedora `.repo` definition with pinned key `2596A99EAAB33821893C0A79458CA832957F5868`, enables `tailscaled`, and retains optional auth-key enrollment |

## Entry points and updater inventory

`setup.sh` and `install.sh` now use the Fedora identity, paths, configuration,
and release artifacts. Their remaining distro behavior will be audited with the
installer and test phases. The original 44 updater scripts were audited; seven
Fedora-package-owned wrappers were removed, leaving the 37 updaters tracked
below.

| Script | Disposition | Status / reason |
|---|---|---|
| `updates/update-aider.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-all.sh` | port | Complete; validates the catalog, runs only its listed updaters, continues after failures, and reports a combined result |
| `updates/update-android-studio.sh` | replace | Complete; delegates a managed installation to the checksum-verifying transactional tarball installer |
| `updates/update-antigravity.sh` | replace | Complete; verifies RPM ownership and performs a targeted DNF refresh/upgrade |
| `updates/update-atuin.sh` | port | Complete; delegates only user-owned Atuin binaries to the checksum-verifying installer |
| `updates/update-aws-cli.sh` | port | Complete; selects RPM architecture and verifies AWS's fingerprint-pinned detached signature before running the v2 installer with `--update` |
| `updates/update-bun.sh` | neutral | Complete; updates only the Bun binary under the configured user-local installation through `bun upgrade` |
| `updates/update-chezmoi.sh` | delete | Complete; removed because Fedora's package and DNF now own chezmoi updates |
| `updates/update-claude.sh` | replace | Complete; upgrades the owning `claude-code` RPM or verified global npm installation |
| `updates/update-cline.sh` | neutral | Complete; npm-owned updater has no distribution package path |
| `updates/update-codex.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-composer.sh` | port | Complete; self-updates only the active standalone, non-RPM Composer PHAR and preserves Composer's home when privilege is required |
| `updates/update-ctop.sh` | port | Complete; validates standalone ownership and uses shared Fedora release architecture mapping |
| `updates/update-cursor-agent.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-deno.sh` | neutral | Complete; updates only the Deno binary under the configured user-local installation through `deno upgrade` |
| `updates/update-dive.sh` | replace | Complete; validates RPM ownership and installs the checksum-verified official RPM release |
| `updates/update-fisher.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-flutter.sh` | neutral | Complete; runs Flutter's native upgrade only from a clean checkout with the exact official Git remote |
| `updates/update-gemini.sh` | neutral | Complete; verifies npm ownership before updating the active global prefix |
| `updates/update-github-copilot.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-gitleaks.sh` | delete | Complete; removed because Fedora's package and DNF now own gitleaks updates |
| `updates/update-go.sh` | port | Complete; uses shared release architecture, official checksums, and transactional replacement with rollback while respecting version pins |
| `updates/update-goose.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-huggingface-cli.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-just.sh` | delete | Complete; removed because Fedora's package and DNF now own just updates |
| `updates/update-lazydocker.sh` | port | Complete; uses RPM ownership checks and delegates to the verified Fedora-aware installer |
| `updates/update-llama-cpp.sh` | neutral | Complete; source-owned update/build path has no distribution package operation |
| `updates/update-mcp-inspector.sh` | neutral | Complete; verifies npm ownership before updating the active global prefix |
| `updates/update-mistral-vibe.sh` | neutral | Complete; Python tool ownership is verified before upgrade |
| `updates/update-node.sh` | neutral | Complete; verifies a clean official NVM checkout, selects the latest upstream tag, and installs the latest Node.js LTS |
| `updates/update-nvim.sh` | delete | Complete; removed because Fedora's current Neovim package and DNF now own updates |
| `updates/update-oh-my-zsh.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-opencode.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-pipx-tools.sh` | neutral | Complete; upgrades only configured applications already owned by pipx |
| `updates/update-pyenv.sh` | neutral | Complete; fast-forwards only a clean checkout with pyenv's exact official remote |
| `updates/update-rbenv.sh` | neutral | Complete; fast-forwards only clean rbenv and ruby-build checkouts with their exact official remotes |
| `updates/update-rclone.sh` | delete | Complete; removed because Fedora's package and DNF now own rclone updates |
| `updates/update-restic.sh` | delete | Complete; removed because Fedora's package and DNF now own restic updates |
| `updates/update-rust.sh` | neutral | Complete; invokes the rustup binary from the configured user-owned Cargo installation |
| `updates/update-starship.sh` | port | Complete; retains checksum-verified atomic replacement and uses shared RPM architecture mapping |
| `updates/update-tpm.sh` | neutral | Complete; Git-owned updater has no distribution package path |
| `updates/update-vscode-extensions.sh` | port | Complete; updates extensions only when the active CLI belongs to the `code` RPM |
| `updates/update-vscode.sh` | port | Complete; verifies `code` RPM ownership and performs a targeted DNF refresh/upgrade |
| `updates/update-yq.sh` | delete | Complete; removed because Fedora's package and DNF now own yq updates |

## Shared package-layer decisions

The initial Phase 1 implementation provides:

- quiet, weak-dependency-disabled DNF package installation with an RPM-backed
  installed check;
- explicit DNF4/DNF5 detection and compatible group installation;
- repository files with both `gpgcheck=1` and `repo_gpgcheck=1`, HTTPS-only
  inputs, a single exact primary-key fingerprint, RPM import only after
  verification, controlled `0644` file installation, and SELinux relabeling when
  `restorecon` is available;
- COPR and user-level Flathub helpers;
- distinct `release_arch` (`amd64`/`arm64`) and `rpm_arch`
  (`x86_64`/`aarch64`) mappings.

Verified references (checked 2026-08-26):

- DNF5 removed DNF4's `groupinstall` alias in favor of
  `dnf group install`: <https://dnf5.readthedocs.io/en/stable/changes_from_dnf4.7.html>
- DNF4's group command and DNF5's group command both install missing packages
  idempotently:
  <https://dnf.readthedocs.io/en/stable/command_ref.html#group-command> and
  <https://dnf5.readthedocs.io/en/latest/commands/group.8.html>
- Flathub documents the user-scoped remote URL and `--user` install model:
  <https://docs.flathub.org/docs/for-app-authors/submission> and
  <https://docs.flathub.org/docs/for-users/user-vs-system-install>

Phase 3 application references (checked 2026-08-26):

- Google's Linux repository page publishes Chrome's active primary fingerprint
  `EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796` and its RPM key procedure:
  <https://www.google.com/linuxrepositories/>. Chrome's Fedora build remains a
  64-bit RPM: <https://support.google.com/chrome/a/answer/9025926>.
- Microsoft's current Fedora instructions publish the VS Code yum URL and key:
  <https://code.visualstudio.com/docs/setup/linux>. The downloaded primary key
  fingerprint is `BC528686B50D79E339D3721CEB3E94ADBE1229CF`.
- Warp's current Fedora instructions publish its RPM URL and both x64 and ARM64
  packages: <https://docs.warp.dev/getting-started/quickstart/installation-and-setup>.
  The downloaded primary key fingerprint is
  `0913165C78D5B7A41B42AC657FF7AB39D60F803F`.
- NordVPN's Fedora troubleshooting path publishes its RPM release repository,
  and the current vendor installer resolves that repository to architecture-specific
  URLs under `https://repo.nordvpn.com/yum/nordvpn/centos/`:
  <https://support.nordvpn.com/hc/en-us/articles/38295918469393-I-can-t-install-or-update-the-NordVPN-app-on-Linux>.
  The downloaded primary key fingerprint is
  `BC5480EFEC5C081CE5BCFBE26B219E535C964CA1`.
- Tailscale publishes a Fedora `.repo` with its stable `$basearch` URL,
  package and repository-metadata signature checks, and repository key URL:
  <https://pkgs.tailscale.com/stable/fedora/tailscale.repo>.
  The downloaded primary key fingerprint is
  `2596A99EAAB33821893C0A79458CA832957F5868`.
- Bitwarden documents a native Linux x64 build and directs ARM64 users to npm:
  <https://bitwarden.com/help/cli/>. Postman publishes both Linux x64 and ARM64
  desktop downloads: <https://www.postman.com/downloads/>.
- Fedora currently publishes both `guake` and `flameshot`:
  <https://packages.fedoraproject.org/pkgs/guake/guake/> and
  <https://packages.fedoraproject.org/pkgs/flameshot/flameshot/>.
- Anthropic documents signed DNF repositories for Claude Code's stable and
  latest channels on Fedora/RHEL, and publishes signing-key fingerprint
  `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`:
  <https://code.claude.com/docs/en/getting-started>.
- Google publishes Antigravity's RPM repository at
  <https://antigravity.google/download/linux>. Its RPMs are signed by
  a subkey of Google's Linux package key, whose active primary fingerprint is
  `EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796`:
  <https://www.google.com/linuxrepositories/>. Artifact Registry explicitly
  does not support DNF repository-metadata signature verification:
  <https://docs.cloud.google.com/artifact-registry/docs/os-packages/rpm/configure>.
- NodeSource's RPM setup publishes the Node.js 22 nodistro repository and
  package key; the downloaded primary fingerprint is
  `242B813831AF09562B6C46F76B88DA4E3AF28A14`:
  <https://github.com/nodesource/distributions>.
- Fedora publishes `pipx` and `libcurl-devel` for the Python CLI and llama.cpp
  dependency paths: <https://packages.fedoraproject.org/pkgs/pipx/pipx/> and
  <https://packages.fedoraproject.org/pkgs/curl/libcurl-devel/>.
- Ollama documents x86_64/aarch64 Linux installation and systemd service setup:
  <https://docs.ollama.com/linux>. Hugging Face documents its standalone CLI
  installer and `hf` update behavior:
  <https://huggingface.co/docs/huggingface_hub/installation>.

Phase 4 updater references (checked 2026-08-26):

- AWS documents Fedora support, x86_64/aarch64 installers, detached-signature
  verification, and signing-key fingerprint
  `FB5DB77FD5C118B80511ADA8A6310ACC4672475C`:
  <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>.
- Bun, Deno, Flutter, Composer, and rustup document their native update commands:
  <https://bun.com/docs/installation>,
  <https://docs.deno.com/runtime/reference/cli/upgrade/>,
  <https://docs.flutter.dev/install/upgrade>,
  <https://getcomposer.org/doc/03-cli.md#self-update-selfupdate>, and
  <https://rust-lang.github.io/rustup/basics.html#keeping-rust-up-to-date>.
- NVM, pyenv, rbenv, and ruby-build publish their canonical Git repositories
  and Git-based update flows:
  <https://github.com/nvm-sh/nvm/blob/master/README.md>,
  <https://github.com/pyenv/pyenv/blob/master/README.md>,
  <https://github.com/rbenv/rbenv/blob/master/README.md>, and
  <https://github.com/rbenv/ruby-build/blob/master/README.md>.
- Go publishes stable release archives and SHA-256 checksums through its official
  download service: <https://go.dev/dl/>.

Phase 5 test and CI references (checked 2026-08-26):

- Fedora's release schedule records Fedora 44's April 2026 final release,
  Fedora 42's May 2026 end of life, and Fedora 44's May 2027 end of life; the
  supported test matrix is therefore Fedora 43 and 44, with 44 as the default:
  <https://fedorapeople.org/groups/schedule/f-44/f-44-key-tasks.html>. Fedora's
  lifecycle policy is documented at
  <https://docs.fedoraproject.org/en-US/releases/lifecycle/>.
- GitHub's official Ubuntu 24.04 runner inventory includes ShellCheck, so the
  workflows retain `ubuntu-latest` as their host and use its preinstalled
  binary while Fedora remains the Docker target:
  <https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md>.
- The Fedora 44 full Docker smoke and idempotency stages each selected all 148
  manifest entries: 77 passed, 0 failed, and 71 were intentionally skipped with
  a Fedora-specific reason. Fedora 43 additionally built successfully and
  passed a focused `system/base.sh` smoke test (1 selected, 1 passed). The test
  image includes `diffutils` because minimal Fedora images do not otherwise
  provide the `cmp` and `diff` commands used by guarded writes and state
  comparisons.

## Phase 6 documentation results

- `README.md`, the operational guides under `docs/`, `CLAUDE.md`, `AGENT.md`,
  `.ai/rules.md`, and `.env.example` now use Fedora 43/44 commands, package and
  service terminology, supported architectures, test matrices, and
  configuration precedence.
- The security and recovery guidance documents firewalld zones, SELinux AVC
  investigation and relabeling, exact RPM-key trust, metadata-signature
  exceptions, and the MOK workflow for Secure Boot kernel modules. It does not
  recommend disabling SELinux, Secure Boot, or RPM signature verification.
- The stable configuration rename is documented below. The original migration
  prompt is retained with a historical-status banner because its Ubuntu/Debian
  references describe the audited source state and acceptance criteria, not a
  supported fallback.
- `GOCACHE=/tmp/fpi-phase6-go-cache make check` passed: ShellCheck covered 192
  shell files, manifest coverage matched all 148 entries, the installer catalog
  matched all 108 selectable items in nine categories, and every local
  regression plus the Go TUI test/vet/build gate passed.
- `make release-dry-run` passed in an isolated copy so existing ignored build
  artifacts were not overwritten. It produced and verified
  `fedora-post-install-0.2.0.tar.gz` with both TUI architectures, valid
  checksums, safe archive paths, configuration precedence, launcher behavior,
  and 248 archive entries.

Phase 6 changed documentation and the example configuration only, so it did not
invalidate the Fedora container results recorded for Phase 5 above.

The current signed `repomd.xml` files used by repositories with metadata
checking enabled were also verified successfully with `gpgv` against the
downloaded pinned keys. NodeSource, Antigravity, Google Cloud CLI, Trivy, and
RPM Fusion do not publish or enable usable DNF metadata signatures for the
configured paths, so they use narrowly documented `repo_gpgcheck=0` exceptions
while retaining `gpgcheck=1`; every key file was inspected locally with GnuPG
rather than trusting search snippets.

No third-party RPM repository URL or fingerprint is accepted into the ledger
until it is verified against that vendor's current primary documentation.

## Identity migration notes

The Fedora fork deliberately does not fall back to the former Ubuntu-named
configuration. Existing users should move their stable config once:

```bash
mv ~/.env-ubuntu-post-install ~/.env-fedora-post-install
```

Replace `UBUNTU_POST_INSTALL_CONFIG` with `FEDORA_POST_INSTALL_CONFIG` in shell
profiles or automation. Completion markers move from `~/.cache/ubuntu-setup/`
to `~/.cache/fedora-setup/`, so the first Fedora run starts with a clean marker
set. The default log similarly moves from `~/ubuntu-setup.log` to
`~/fedora-setup.log`; old logs and markers are not deleted.

The installer now manages `~/.local/bin/fedora-post-install` under
`~/.local/share/fedora-post-install`. Its refusal to overwrite an existing
unmanaged symlink or file remains covered by the installer regressions.
