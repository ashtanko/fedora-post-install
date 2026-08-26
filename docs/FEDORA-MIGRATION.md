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
| 3 — installer ports | In progress | The complete `essentials/`, `system/`, `apps/`, `dev/`, `tools/`, `ide/`, and `mobile/` categories are ported; the other categories remain pending |
| 4 — updater ports | In progress | Updaters coupled to completed categories use RPM ownership and Fedora architecture helpers; the remaining category audit is pending |
| 5 — Fedora tests and CI | Not started | Docker image, release matrix, manifest, and contracts still target Ubuntu |
| 6 — documentation | Not started | Identity references are renamed; distro-specific package, security, testing, and troubleshooting claims still need Fedora rewrites |

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
| `ai/aider.sh` | neutral | Audit pending; user-local installer |
| `ai/antigravity.sh` | replace | Pending; replace signed APT channel with a verified RPM or official standalone channel |
| `ai/claude.sh` | replace | Pending; replace signed APT channel with Anthropic's Fedora-supported channel or standalone installer |
| `ai/cline.sh` | port | Pending; replace Debian/Node prerequisites with Fedora packages |
| `ai/codex.sh` | neutral | Audit pending; official standalone installer |
| `ai/cursor-agent.sh` | neutral | Audit pending; user-local upstream installer |
| `ai/fabric.sh` | neutral | Audit pending; Go/user-local installation |
| `ai/gemini.sh` | port | Pending; replace NodeSource APT bootstrap with its RPM equivalent |
| `ai/github-copilot.sh` | neutral | Audit pending; user-local upstream installer |
| `ai/goose.sh` | neutral | Audit pending; user-local upstream installer |
| `ai/huggingface-cli.sh` | port | Pending; translate Python/pipx prerequisites |
| `ai/litellm.sh` | port | Pending; translate Python/pipx prerequisites |
| `ai/llama-cpp.sh` | port | Pending; use Fedora build tool and library package names |
| `ai/llm-cli.sh` | port | Pending; translate Python/pipx prerequisites |
| `ai/mcp-inspector.sh` | port | Pending; replace Debian/Node prerequisites with Fedora packages |
| `ai/mistral-vibe.sh` | neutral | Audit pending; Python user-local installation |
| `ai/ollama-models.sh` | neutral | Audit pending; talks to an existing Ollama service |
| `ai/ollama.sh` | port | Pending; audit installer prerequisites, systemd, and SELinux labels |
| `ai/opencode.sh` | neutral | Audit pending; user-local upstream installer |
| `ai/prompt-runner.sh` | port | Pending; translate packaged CLI prerequisites |
| `ai/qwen-code.sh` | neutral | Audit pending; user-local package-manager installation |

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
| `vpn/nord.sh` | port | Pending; replace Debian-oriented vendor setup with NordVPN's Fedora repository path |
| `vpn/tailscale.sh` | port | Pending; install from Tailscale's Fedora `.repo` definition with verified trust settings |

## Entry points and updater inventory

`setup.sh` and `install.sh` now use the Fedora identity, paths, configuration,
and release artifacts. Their remaining distro behavior will be audited with the
installer and test phases. The 44 updater scripts are tracked below so Phase 4
can update them in lockstep with their installers.

| Script | Disposition | Status / reason |
|---|---|---|
| `updates/update-aider.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-all.sh` | port | Pending; orchestration, output, and Fedora ownership audit |
| `updates/update-android-studio.sh` | replace | Complete; delegates a managed installation to the checksum-verifying transactional tarball installer |
| `updates/update-antigravity.sh` | replace | Pending; remove APT ownership path |
| `updates/update-atuin.sh` | port | Complete; delegates only user-owned Atuin binaries to the checksum-verifying installer |
| `updates/update-aws-cli.sh` | port | Pending; replace Debian package ownership checks |
| `updates/update-bun.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-chezmoi.sh` | delete | Complete; removed because Fedora's package and DNF now own chezmoi updates |
| `updates/update-claude.sh` | replace | Pending; remove APT ownership path and match the selected installer |
| `updates/update-cline.sh` | neutral | Audit pending; npm-owned updater |
| `updates/update-codex.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-composer.sh` | port | Pending; translate packaged prerequisites/ownership checks |
| `updates/update-ctop.sh` | port | Complete; validates standalone ownership and uses shared Fedora release architecture mapping |
| `updates/update-cursor-agent.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-deno.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-dive.sh` | replace | Complete; validates RPM ownership and installs the checksum-verified official RPM release |
| `updates/update-fisher.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-flutter.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-gemini.sh` | neutral | Audit pending; npm ownership logic |
| `updates/update-github-copilot.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-gitleaks.sh` | delete | Complete; removed because Fedora's package and DNF now own gitleaks updates |
| `updates/update-go.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-goose.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-huggingface-cli.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-just.sh` | delete | Complete; removed because Fedora's package and DNF now own just updates |
| `updates/update-lazydocker.sh` | port | Complete; uses RPM ownership checks and delegates to the verified Fedora-aware installer |
| `updates/update-llama-cpp.sh` | neutral | Audit pending; source update/build path |
| `updates/update-mcp-inspector.sh` | neutral | Audit pending; npm ownership logic |
| `updates/update-mistral-vibe.sh` | neutral | Audit pending; Python-owned updater |
| `updates/update-node.sh` | neutral | Audit pending; NVM-owned updater |
| `updates/update-nvim.sh` | delete | Complete; removed because Fedora's current Neovim package and DNF now own updates |
| `updates/update-oh-my-zsh.sh` | neutral | Complete; tool-owned updater has no distribution package path |
| `updates/update-opencode.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-pipx-tools.sh` | neutral | Audit pending; pipx-owned updater |
| `updates/update-pyenv.sh` | neutral | Audit pending; Git-owned updater |
| `updates/update-rbenv.sh` | neutral | Audit pending; Git-owned updater |
| `updates/update-rclone.sh` | delete | Complete; removed because Fedora's package and DNF now own rclone updates |
| `updates/update-restic.sh` | delete | Complete; removed because Fedora's package and DNF now own restic updates |
| `updates/update-rust.sh` | neutral | Audit pending; rustup-owned updater |
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
- Bitwarden documents a native Linux x64 build and directs ARM64 users to npm:
  <https://bitwarden.com/help/cli/>. Postman publishes both Linux x64 and ARM64
  desktop downloads: <https://www.postman.com/downloads/>.
- Fedora currently publishes both `guake` and `flameshot`:
  <https://packages.fedoraproject.org/pkgs/guake/guake/> and
  <https://packages.fedoraproject.org/pkgs/flameshot/flameshot/>.

All three current `repomd.xml` signatures were also verified successfully with
`gpgv` against the downloaded pinned keys before enabling `repo_gpgcheck=1`;
the key files were inspected locally with GnuPG rather than trusting search
snippets.

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
