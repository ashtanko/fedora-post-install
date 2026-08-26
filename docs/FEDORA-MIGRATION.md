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
| 3 — installer ports | In progress | The complete `essentials/`, `system/`, `apps/`, and `dev/` categories are ported; the other categories remain pending |
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
| `ide/android-studio.sh` | replace | Pending; replace Snap with the official tarball or Flathub and migrate its updater in lockstep |
| `ide/cursor.sh` | port | Pending; install Fedora FUSE support or extract the AppImage; use shared architecture mapping |
| `ide/dbeaver.sh` | port | Pending; use DBeaver's RPM repository and pinned signing key |
| `ide/jetbrains-toolbox.sh` | port | Pending; retain tarball and translate GUI/archive prerequisites |
| `ide/nvim.sh` | neutral | Audit pending; verified GitHub release archive with its own architecture mapping |
| `ide/vscode-extensions.sh` | neutral | Audit pending; operates through an existing editor CLI |
| `ide/zed.sh` | neutral | Audit pending; official user-local installer |

### `mobile/`

| Script | Disposition | Status / reason |
|---|---|---|
| `mobile/zip_flutter_plugin.sh` | neutral | Audit pending; manual archive utility |

### `software/`

| Script | Disposition | Status / reason |
|---|---|---|
| `software/boxes.sh` | port | Pending; use Fedora virtualization packages and groups |
| `software/virtualbox.sh` | replace | Pending; choose a verified Fedora RPM source and document akmods/Secure Boot MOK enrollment |
| `software/vmware.sh` | port | Pending; use Fedora kernel-devel, compiler, Perl, and libelf package names |

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
| `tools/atuin.sh` | port | Pending; retain upstream installer and translate prerequisites |
| `tools/backup-home.sh` | neutral | Audit pending; user-data archive utility |
| `tools/btop.sh` | port | Pending; install Fedora repository package |
| `tools/cli-tools.sh` | port | Pending; use Fedora packages and delete `batcat` compatibility links |
| `tools/ctop.sh` | port | Pending; retain verified release binary and replace `dpkg` architecture lookup |
| `tools/dive.sh` | replace | Pending; replace GitHub DEB installation with a Fedora-compatible release asset |
| `tools/docker-maintenance.sh` | neutral | Audit pending; Docker CLI maintenance only |
| `tools/dotfiles.sh` | port | Pending; use Fedora package or retained upstream installer after audit |
| `tools/fish.sh` | port | Pending; install Fedora package and audit login-shell path |
| `tools/fonts.sh` | port | Pending; translate archive/font-cache prerequisites |
| `tools/git-config.sh` | neutral | Audit pending; Git configuration only |
| `tools/gitleaks.sh` | port | Pending; retain verified release archive and use shared architecture mapping |
| `tools/hadolint.sh` | port | Pending; retain release binary and translate prerequisites/architecture |
| `tools/just.sh` | port | Pending; retain verified release archive and use shared architecture mapping |
| `tools/lazydocker.sh` | port | Pending; retain verified release archive and use shared architecture mapping |
| `tools/modern-cli.sh` | port | Pending; use Fedora packages and delete `fdfind` compatibility links |
| `tools/network-tools.sh` | port | Pending; map Debian network utility package names to Fedora |
| `tools/pre-commit-setup.sh` | port | Pending; translate pipx/Python prerequisites |
| `tools/rclone.sh` | port | Pending; retain verified release archive and replace Debian package handling |
| `tools/restic.sh` | port | Pending; install Fedora repository package |
| `tools/starship.sh` | port | Pending; retain verified release archive and use shared architecture mapping |
| `tools/system-maintenance.sh` | replace | Pending; use DNF cleanup, retain Flatpak/journal cleanup, and remove Snap handling |
| `tools/tmux-config.sh` | port | Pending; install Fedora tmux/Git prerequisites |
| `tools/trivy.sh` | port | Pending; use Aqua's RPM repository and a pinned signing key |
| `tools/wireshark.sh` | replace | Pending; replace debconf preseeding with the wireshark group and `dumpcap` capabilities |
| `tools/yq.sh` | port | Pending; retain checksum-verified release binary and use shared architecture mapping |
| `tools/zsh.sh` | port | Pending; install Fedora package and retain safe Oh My Zsh download flow |

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
| `updates/update-android-studio.sh` | replace | Pending; must match the new tarball or Flatpak installation |
| `updates/update-antigravity.sh` | replace | Pending; remove APT ownership path |
| `updates/update-atuin.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-aws-cli.sh` | port | Pending; replace Debian package ownership checks |
| `updates/update-bun.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-chezmoi.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-claude.sh` | replace | Pending; remove APT ownership path and match the selected installer |
| `updates/update-cline.sh` | neutral | Audit pending; npm-owned updater |
| `updates/update-codex.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-composer.sh` | port | Pending; translate packaged prerequisites/ownership checks |
| `updates/update-ctop.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-cursor-agent.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-deno.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-dive.sh` | replace | Pending; match the new Fedora-compatible release mechanism |
| `updates/update-fisher.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-flutter.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-gemini.sh` | neutral | Audit pending; npm ownership logic |
| `updates/update-github-copilot.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-gitleaks.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-go.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-goose.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-huggingface-cli.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-just.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-lazydocker.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-llama-cpp.sh` | neutral | Audit pending; source update/build path |
| `updates/update-mcp-inspector.sh` | neutral | Audit pending; npm ownership logic |
| `updates/update-mistral-vibe.sh` | neutral | Audit pending; Python-owned updater |
| `updates/update-node.sh` | neutral | Audit pending; NVM-owned updater |
| `updates/update-nvim.sh` | neutral | Audit pending; verified release updater |
| `updates/update-oh-my-zsh.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-opencode.sh` | neutral | Audit pending; tool-owned updater |
| `updates/update-pipx-tools.sh` | neutral | Audit pending; pipx-owned updater |
| `updates/update-pyenv.sh` | neutral | Audit pending; Git-owned updater |
| `updates/update-rbenv.sh` | neutral | Audit pending; Git-owned updater |
| `updates/update-rclone.sh` | port | Pending; replace Debian package/archive handling |
| `updates/update-restic.sh` | port | Pending; DNF-owned install may move to `skipped.txt` |
| `updates/update-rust.sh` | neutral | Audit pending; rustup-owned updater |
| `updates/update-starship.sh` | port | Pending; replace Debian architecture detection |
| `updates/update-tpm.sh` | neutral | Audit pending; Git-owned updater |
| `updates/update-vscode-extensions.sh` | port | Complete; updates extensions only when the active CLI belongs to the `code` RPM |
| `updates/update-vscode.sh` | port | Complete; verifies `code` RPM ownership and performs a targeted DNF refresh/upgrade |
| `updates/update-yq.sh` | port | Pending; replace Debian architecture detection |

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
