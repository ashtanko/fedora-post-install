# Fedora migration ledger

This file tracks the conversion from `ubuntu-post-install` to
`fedora-post-install`. Fedora is the only intended target. A `neutral`
classification means the current mechanism appears distribution-independent;
it does **not** mean the Fedora audit or runtime validation is complete.

## Progress

| Phase | State | Notes |
|---|---|---|
| 0 — branch and inventory | Complete | `feat/fedora-migration` created; all 110 installer/manual scripts and 44 updater scripts inventoried below |
| 1 — shared package layer | In progress | `lib/pkg.bash` and isolated regression coverage added; installer callers are not migrated yet |
| 2 — identity rename | Complete | Runtime paths, configuration, TUI/module, CLI, release artifacts, workflows, tests, and documentation use the Fedora identity |
| 3 — installer ports | Not started | Category scripts still contain Debian/Ubuntu package paths |
| 4 — updater ports | Not started | Updater ownership and DNF-managed skip decisions still require audit |
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
| `apps/bitwarden-cli.sh` | port | Pending; use shared release architecture and Fedora archive prerequisites |
| `apps/browsers.sh` | port | Pending; use Google's RPM repository and pinned signing key |
| `apps/flameshot.sh` | port | Pending; install Fedora repository package |
| `apps/guake.sh` | port | Pending; install Fedora repository package |
| `apps/postman.sh` | port | Pending; retain official tarball and translate prerequisites |
| `apps/vscode.sh` | port | Pending; use Microsoft's VS Code yum repository and pinned signing key |
| `apps/warp.sh` | port | Pending; replace local DEB/APT path with Warp's RPM channel |

### `dev/`

| Script | Disposition | Status / reason |
|---|---|---|
| `dev/aws-cli.sh` | port | Pending; retain verified upstream archives and replace Session Manager APT path |
| `dev/azure-cli.sh` | port | Pending; replace Ubuntu installer/repository path with Microsoft's RPM channel |
| `dev/bun.sh` | port | Pending; retain upstream installer and translate prerequisites |
| `dev/cpp.sh` | port | Pending; map compiler, debugger, and development group package names |
| `dev/databases.sh` | replace | Pending; map Fedora database clients and resolve Redis-to-Valkey behavior |
| `dev/deno.sh` | port | Pending; retain upstream installer and translate prerequisites |
| `dev/docker-rootless.sh` | port | Pending; translate rootless dependencies and validate SELinux/subuid behavior |
| `dev/docker.sh` | port | Pending; use Docker's Fedora yum repository and Desktop RPM; document Podman coexistence |
| `dev/dotnet.sh` | replace | Pending; prefer Fedora's native `dotnet-sdk-*` packages |
| `dev/flutter.sh` | port | Pending; translate Linux desktop and Android prerequisite packages |
| `dev/gcloud.sh` | port | Pending; use Google's yum repository with a pinned key fingerprint |
| `dev/go.sh` | port | Pending; retain verified archive and replace `dpkg` architecture lookup |
| `dev/java.sh` | replace | Pending; use `java-*-openjdk-devel` packages and Fedora `alternatives` |
| `dev/kubernetes.sh` | port | Pending; use upstream yum repositories and shared architecture helpers |
| `dev/node.sh` | neutral | Audit pending; NVM user-local install has no distro package path |
| `dev/php.sh` | replace | Pending; remove PPA/suite probing and select Fedora native PHP or verified Remi repositories |
| `dev/podman.sh` | port | Pending; use Fedora packages and validate rootless SELinux/subuid behavior |
| `dev/python.sh` | port | Pending; replace `build-essential` and Debian development package names |
| `dev/ruby.sh` | port | Pending; replace `build-essential` and Debian development package names |
| `dev/rust.sh` | neutral | Audit pending; rustup user-local install has no distro package path |
| `dev/terraform.sh` | port | Pending; use HashiCorp's RPM repository and Fedora package names |

### `essentials/`

| Script | Disposition | Status / reason |
|---|---|---|
| `essentials/auto-updates.sh` | replace | Pending; rewrite around `dnf-automatic` security updates and its timer |
| `essentials/fail2ban.sh` | replace | Pending; add `fail2ban-firewalld` and the systemd backend |
| `essentials/firewall.sh` | replace | Pending; rewrite UFW behavior around firewalld zones and services |
| `essentials/fstrim.sh` | replace | Pending; detect Fedora's normally enabled `fstrim.timer` and no-op cleanly |
| `essentials/gnome-settings.sh` | neutral | Audit pending; GNOME `gsettings` behavior is distro-independent |
| `essentials/journald.sh` | port | Pending; retain the journal cap but audit Fedora defaults and restore labels on the drop-in |
| `essentials/locale-timezone.sh` | port | Pending; replace Debian locale generation and package assumptions |
| `essentials/lynis.sh` | port | Pending; install the Fedora repository package |
| `essentials/motd-news.sh` | delete | Confirmed Ubuntu-only: the script only disables Ubuntu motd-news/ESM advertising; removal pending catalog/manifest/docs synchronization |
| `essentials/swap.sh` | replace | Pending; respect zram and implement an explicit Btrfs-safe disk-swap policy |
| `essentials/sysctl-limits.sh` | neutral | Audit pending; standard sysctl/limits drop-ins, with SELinux label validation required |
| `essentials/system-info.sh` | neutral | Audit pending; read-only system inventory |

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
| `system/base.sh` | port | Pending; use DNF upgrade and the development-tools group |
| `system/gpg.sh` | port | Pending; install Fedora GnuPG prerequisites |
| `system/hostname.sh` | port | Pending; remove the Ubuntu-specific assumption that every host needs a `127.0.1.1` entry |
| `system/hosts-dns.sh` | neutral | Audit pending; systemd-resolved drop-in with a clean NetworkManager fallback/skip |
| `system/keyboard.sh` | port | Pending; use Fedora keyd package and validate `/dev/uinput`/SELinux behavior |
| `system/ntp.sh` | port | Pending; use Fedora chrony package checks and RPM verification |
| `system/ssh.sh` | port | Pending; translate OpenSSH client prerequisites |
| `system/sudoers.sh` | neutral | Audit pending; validated sudoers drop-in is distro-independent |
| `system/user-groups.sh` | port | Pending; default to `docker dialout wireshark`, use `wheel`, and drop `plugdev` |

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
| `updates/update-vscode-extensions.sh` | port | Pending; remove Debian package ownership assumptions |
| `updates/update-vscode.sh` | port | Pending; DNF-owned install likely moves to `skipped.txt` |
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
