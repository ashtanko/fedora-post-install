# Script Inventory

Every installer script can run standalone with `bash <path>`, or from the [`setup.sh`](../setup.sh) menu when registered there. Scripts load shared configuration, include re-run guards appropriate to their installer, and re-exec under `bash` if invoked via `sh`.

## essentials/

OS bootstrap — run these first on a fresh install.

| Script | Purpose |
|---|---|
| [swap.sh](../essentials/swap.sh) | Respects Fedora's active zram swap; optionally creates a Btrfs-safe disk swap file when `ENABLE_DISK_SWAP=yes` |
| [firewall.sh](../essentials/firewall.sh) | Enables firewalld and allows its SSH service in the existing/default zone; set `ENABLE_FIREWALL=no` to skip |
| [auto-updates.sh](../essentials/auto-updates.sh) | Enables automatic DNF security updates through the DNF5 or DNF4 timer; set `ENABLE_AUTO_UPDATES=no` to skip |
| [locale-timezone.sh](../essentials/locale-timezone.sh) | Sets timezone (from `$TZ` or ipapi.co) and installs the Fedora language pack for `$LOCALE` (default `en_US.UTF-8`) |
| [gnome-settings.sh](../essentials/gnome-settings.sh) | Idempotent gsettings: night light, tap-to-click, fixed workspaces, hidden files, etc. Skips if not GNOME |
| [journald.sh](../essentials/journald.sh) | Caps the systemd journal to `$JOURNAL_MAX_USE` (default `200M`) via a journald.conf.d drop-in |
| [fstrim.sh](../essentials/fstrim.sh) | Enables `fstrim.timer` for periodic SSD/NVMe TRIM; skips on rotational-only disks |
| [sysctl-limits.sh](../essentials/sysctl-limits.sh) | Raises inotify watch/instance limits and the open-file (`nofile`) limit for IDEs, docker, and bundlers |
| [system-info.sh](../essentials/system-info.sh) | One-shot dump of CPU/RAM/GPU/disk/distro to `~/system-info-<ts>.log` |
| [fail2ban.sh](../essentials/fail2ban.sh) | SSH protection using Fedora's fail2ban/firewalld integration and systemd journal backend; set `ENABLE_FAIL2BAN=no` to skip |
| [lynis.sh](../essentials/lynis.sh) | One-shot Lynis security audit dumped to `~/lynis-audit-<ts>.log` |

## system/

Foundations — git, build tools, keys.

| Script | Purpose |
|---|---|
| [base.sh](../system/base.sh) | Runs `dnf upgrade --refresh`, installs the development-tools group, and adds git/curl/wget/GNOME Tweaks |
| [hostname.sh](../system/hostname.sh) | Sets the Fedora hostname from `$NEW_HOSTNAME` or a prompt; does not add Debian-style `/etc/hosts` entries |
| [user-groups.sh](../system/user-groups.sh) | Adds the invoking user to Fedora groups (`$EXTRA_USER_GROUPS`, default wheel/docker/dialout/wireshark); skips groups not installed yet |
| [ntp.sh](../system/ntp.sh) | Installs chrony and enables the Fedora `chronyd` service when systemd is active |
| [hosts-dns.sh](../system/hosts-dns.sh) | Configures an already-active systemd-resolved instance; leaves Fedora NetworkManager connection DNS unchanged |
| [sudoers.sh](../system/sudoers.sh) | Opt-in only (`$SUDO_TIMESTAMP_TIMEOUT_MINUTES`): extends the sudo timestamp timeout via a `visudo -cf`-validated drop-in. Never configures passwordless sudo |
| [keyboard.sh](../system/keyboard.sh) | keyd from the `alternateved/keyd` COPR; validates `/dev/uinput`, restores SELinux labels, and applies macOS-style modifiers |
| [gpg.sh](../system/gpg.sh) | Fedora `gnupg2` prerequisite, GPG key generation/selection, and git signing configuration |
| [ssh.sh](../system/ssh.sh) | Fedora `openssh-clients` prerequisite, ed25519 SSH key, and shell ssh-agent autostart block |

## apps/

GUI applications.

| Script | Purpose |
|---|---|
| [browsers.sh](../apps/browsers.sh) | Google Chrome from Google's signed x86_64 RPM repository; other architectures are rejected before repository changes |
| [guake.sh](../apps/guake.sh) | Guake drop-down terminal from Fedora's repositories |
| [postman.sh](../apps/postman.sh) | Postman API client — official x86_64/aarch64 tarball transactionally installed into `$POSTMAN_INSTALL_DIR`, with `~/.local/bin` symlink and `.desktop` entry |
| [warp.sh](../apps/warp.sh) | Warp terminal from its signed x86_64/aarch64 RPM repository |
| [vscode.sh](../apps/vscode.sh) | VS Code from Microsoft's signed yum repository |
| [bitwarden-cli.sh](../apps/bitwarden-cli.sh) | Bitwarden CLI (`bw`) — official x86_64 Linux zip |
| [flameshot.sh](../apps/flameshot.sh) | Flameshot annotated screenshot tool from Fedora's repositories |

## dev/

Language runtimes and SDKs.

| Script | Purpose |
|---|---|
| [java.sh](../dev/java.sh) | Fedora OpenJDK 8/11/17/21/25 — interactive menu or `JAVA_VERSION` env (switch defaults via `alternatives`) |
| [docker.sh](../dev/docker.sh) | Docker Engine + Docker Desktop + user group |
| [docker-rootless.sh](../dev/docker-rootless.sh) | Rootless Docker daemon for the current user (`dockerd-rootless-setuptool.sh`); reports missing subuid/subgid rather than rewriting them |
| [flutter.sh](../dev/flutter.sh) | Flutter SDK (stable) + Linux desktop dependencies; Android SDK setup remains separate |
| [node.sh](../dev/node.sh) | Node.js via NVM — installs latest LTS |
| [python.sh](../dev/python.sh) | Python 3 + pyenv + pipx + poetry |
| [rust.sh](../dev/rust.sh) | Rust toolchain via rustup |
| [go.sh](../dev/go.sh) | Latest Go SDK — version detection with fallback (VERSION endpoint → JSON) |
| [databases.sh](../dev/databases.sh) | PostgreSQL, MariaDB/MySQL, Valkey, SQLite, and MongoDB CLI clients + pgcli/mycli/litecli via pipx |
| [kubernetes.sh](../dev/kubernetes.sh) | kubectl + helm + k9s + kind + kustomize |
| [aws-cli.sh](../dev/aws-cli.sh) | AWS CLI v2 + Session Manager plugin from signature-verified official downloads |
| [terraform.sh](../dev/terraform.sh) | Terraform (signed HashiCorp RPM repo) + tflint (checksum-verified) + tfsec (signature-verified) |
| [dotnet.sh](../dev/dotnet.sh) | Fedora-native .NET SDK; `$DOTNET_VERSION` picks the major.minor (default `8.0`) |
| [ruby.sh](../dev/ruby.sh) | Ruby via rbenv + ruby-build + bundler; `$RUBY_VERSION` pins a version (default: latest stable) |
| [gcloud.sh](../dev/gcloud.sh) | Google Cloud CLI via Google's signed RPM repo + `gke-gcloud-auth-plugin` for kubectl/GKE |
| [azure-cli.sh](../dev/azure-cli.sh) | Azure CLI (`az`) via Microsoft's signed RPM repository |
| [podman.sh](../dev/podman.sh) | Podman + podman-compose (rootless containers); reports missing subuid/subgid rather than rewriting them |
| [deno.sh](../dev/deno.sh) | Deno runtime via official installer into `$DENO_INSTALL` |
| [bun.sh](../dev/bun.sh) | Bun runtime/package manager via official installer into `$BUN_INSTALL` |
| [php.sh](../dev/php.sh) | Fedora-native PHP + common extensions + Composer (signature-verified) |
| [cpp.sh](../dev/cpp.sh) | C/C++ toolchain: gcc/clang, cmake, ninja, ccache, gdb/lldb, clang-format/tidy, cppcheck, valgrind |

## tools/

Shell, CLI, and dev helpers.

| Script | Purpose |
|---|---|
| [zsh.sh](../tools/zsh.sh) | Zsh + Oh My Zsh; set `INSTALL_OH_MY_ZSH=no` to skip OMZ |
| [fish.sh](../tools/fish.sh) | Fish shell + Fisher plugin manager; optionally changes the login shell |
| [starship.sh](../tools/starship.sh) | Starship cross-shell prompt, initialized for installed Bash, Zsh, and Fish shells |
| [cli-tools.sh](../tools/cli-tools.sh) | bat, fzf, ripgrep, eza, jq, htop, tmux, tree, gh (GitHub CLI) |
| [modern-cli.sh](../tools/modern-cli.sh) | lazygit, delta, zoxide, btop, direnv, fd, dust, hyperfine, tldr (tealdeer) |
| [btop.sh](../tools/btop.sh) | btop — modern resource/process monitor from Fedora's repositories |
| [fonts.sh](../tools/fonts.sh) | JetBrains Mono, Fira Code, Hack — all Nerd Font variants |
| [git-config.sh](../tools/git-config.sh) | Opinionated git defaults (rebase pull, autosetup, aliases, global gitignore, optional GPG signing) |
| [pre-commit-setup.sh](../tools/pre-commit-setup.sh) | Fedora's pre-commit package + git template hook + starter `.pre-commit-config.yaml` |
| [backup-home.sh](../tools/backup-home.sh) | Tar (optionally GPG-encrypted) backup of SSH/GPG/AWS/.config to `$BACKUP_DIR` |
| [system-maintenance.sh](../tools/system-maintenance.sh) | DNF autoremove/cache cleanup, journal vacuum, Docker/Flatpak prune, user-cache trim |
| [wireshark.sh](../tools/wireshark.sh) | Fedora Wireshark GUI/CLI packages; configures non-root capture through the `wireshark` group and `dumpcap` capabilities |
| [dotfiles.sh](../tools/dotfiles.sh) | Fedora's chezmoi dotfiles manager; optionally clones `$DOTFILES_REPO` (never auto-applies) |
| [rclone.sh](../tools/rclone.sh) | Fedora's rclone cloud storage sync package — pairs with `backup-home.sh` for offsite copies |
| [lazydocker.sh](../tools/lazydocker.sh) | lazydocker terminal UI for Docker (GitHub release, checksum-verified) |
| [ctop.sh](../tools/ctop.sh) | ctop — live per-container CPU/memory/net/IO metrics (GitHub release, checksum-verified) |
| [dive.sh](../tools/dive.sh) | dive — explore Docker image layers (official GitHub release RPM, checksum-verified) |
| [hadolint.sh](../tools/hadolint.sh) | Fedora's hadolint Dockerfile linter package |
| [trivy.sh](../tools/trivy.sh) | Trivy — image, filesystem, and IaC vulnerability scanner via Aqua's signed RPM repository |
| [docker-maintenance.sh](../tools/docker-maintenance.sh) | Docker-only disk reclaim: prunes containers, networks, images, and build cache with before/after `docker system df`; volumes are opt-in |
| [tmux-config.sh](../tools/tmux-config.sh) | TPM plugin manager + starter `~/.tmux.conf` (written only if absent); prefix rebound to `Ctrl-a` |
| [restic.sh](../tools/restic.sh) | Fedora's restic package — deduplicated, encrypted incremental backups with native rclone backend support |
| [network-tools.sh](../tools/network-tools.sh) | mtr, nmap, dig, ss, lsof, nc, iperf3, HTTPie, whois |
| [gitleaks.sh](../tools/gitleaks.sh) | Fedora's gitleaks secret scanner package (also wired as a pre-commit hook by `pre-commit-setup.sh`) |
| [yq.sh](../tools/yq.sh) | Fedora's yq package — the YAML counterpart to `jq` |
| [just.sh](../tools/just.sh) | Fedora's `just` command-runner package |
| [atuin.sh](../tools/atuin.sh) | Checksum-verified current Atuin release, wired into Bash, Zsh, and Fish; sync is opt-in |

## ide/

Editors and IDEs.

| Script | Purpose |
|---|---|
| [zed.sh](../ide/zed.sh) | Zed editor (preview channel) via official installer |
| [vscode-extensions.sh](../ide/vscode-extensions.sh) | Bulk-install extensions from `$VSCODE_EXTENSIONS` (whitespace-separated) |
| [jetbrains-toolbox.sh](../ide/jetbrains-toolbox.sh) | JetBrains Toolbox app + desktop entry; pick IDEs from the Toolbox UI |
| [nvim.sh](../ide/nvim.sh) | Latest Neovim from official GitHub release tarball; writes starter `init.lua` if absent |
| [android-studio.sh](../ide/android-studio.sh) | Android Studio via snap (`--classic`) — the SDK/emulator/device tooling `dev/flutter.sh` leaves out of scope |
| [cursor.sh](../ide/cursor.sh) | Cursor editor (official AppImage, amd64 only) — GUI counterpart to `ai/cursor-agent.sh`'s CLI agent |
| [dbeaver.sh](../ide/dbeaver.sh) | DBeaver Community via its official apt repo — GUI counterpart to `dev/databases.sh`'s CLI clients |

## ai/

LLM tooling and CLIs.

| Script | Purpose |
|---|---|
| [ollama.sh](../ai/ollama.sh) | Ollama via official installer; ensures systemd service is up |
| [ollama-models.sh](../ai/ollama-models.sh) | Pulls the whitespace-separated `$OLLAMA_MODELS` list; requires a running Ollama service and has no default downloads |
| [llama-cpp.sh](../ai/llama-cpp.sh) | Build llama.cpp from source (CMake, Release); symlinks main binaries to `~/.local/bin` |
| [claude.sh](../ai/claude.sh) | Claude Code CLI from Anthropic's signed Ubuntu APT repository (`$CLAUDE_CHANNEL`: stable/latest) |
| [codex.sh](../ai/codex.sh) | OpenAI Codex CLI via the official standalone installer; `$CODEX_RELEASE` can pin a release |
| [gemini.sh](../ai/gemini.sh) | Google Gemini CLI (installs Node via verified NodeSource repo if missing) |
| [github-copilot.sh](../ai/github-copilot.sh) | GitHub Copilot CLI via the official user-local installer; `$COPILOT_VERSION` can pin a release |
| [huggingface-cli.sh](../ai/huggingface-cli.sh) | Standalone `hf` CLI for Hub authentication, model downloads, uploads, and cache management; skips the installer's optional agent skill |
| [aider.sh](../ai/aider.sh) | Aider coding CLI via its official isolated installer |
| [goose.sh](../ai/goose.sh) | Provider-neutral goose agent CLI; installs without launching its provider configuration wizard |
| [qwen-code.sh](../ai/qwen-code.sh) | Qwen Code terminal agent via the official standalone installer |
| [cursor-agent.sh](../ai/cursor-agent.sh) | Cursor Agent CLI via Cursor's official user-local installer |
| [mistral-vibe.sh](../ai/mistral-vibe.sh) | Mistral Vibe coding agent, including its ACP command, via the official installer |
| [cline.sh](../ai/cline.sh) | Cline terminal agent via npm; `$CLINE_VERSION` can pin a release |
| [fabric.sh](../ai/fabric.sh) | Fabric CLI for reusable prompt patterns and content workflows |
| [llm-cli.sh](../ai/llm-cli.sh) | Provider-neutral `llm` command installed in an isolated pipx environment; `$LLM_VERSION` can pin a release |
| [litellm.sh](../ai/litellm.sh) | LiteLLM OpenAI-compatible proxy CLI in an isolated pipx environment; latest installs align FastAPI/Starlette with LiteLLM's current proxy constraints, while `$LITELLM_VERSION` can pin a release |
| [mcp-inspector.sh](../ai/mcp-inspector.sh) | MCP Inspector web, TUI, and CLI debugger via npm; `$MCP_INSPECTOR_VERSION` can pin a release |
| [antigravity.sh](../ai/antigravity.sh) | Google Antigravity IDE via Google's signed APT repo (key fingerprint pinned); self-updates through apt |
| [opencode.sh](../ai/opencode.sh) | opencode CLI via official installer |
| [prompt-runner.sh](../ai/prompt-runner.sh) | Installs `prompt` command — runs text/.prompt files against ollama / openai / anthropic |

## updates/

Maintenance wrappers for tools already installed by this project. They are not part of the fresh-install menu or its completion-marker flow. Each individual updater skips successfully when its tool is absent; [`update-all.sh`](../updates/update-all.sh) runs the full supported set and reports any failures.

| Script | Purpose |
|---|---|
| [update-aider.sh](../updates/update-aider.sh) | Upgrade the repository-managed Aider CLI |
| [update-all.sh](../updates/update-all.sh) | Run every supported updater, continue after individual failures, and return a combined result |
| [update-android-studio.sh](../updates/update-android-studio.sh) | Refresh the installed Android Studio snap |
| [update-antigravity.sh](../updates/update-antigravity.sh) | Upgrade the Antigravity package from Google's configured APT repository |
| [update-atuin.sh](../updates/update-atuin.sh) | Install the checksum-verified latest Atuin release asset |
| [update-aws-cli.sh](../updates/update-aws-cli.sh) | Verify AWS's detached signature, then update the repository-managed AWS CLI v2 installation |
| [update-bun.sh](../updates/update-bun.sh) | Upgrade the Bun binary installed under `$BUN_INSTALL` |
| [update-claude.sh](../updates/update-claude.sh) | Upgrade Claude Code from Anthropic's configured APT channel, or from npm when the active executable is npm-owned |
| [update-cline.sh](../updates/update-cline.sh) | Update the active global npm installation of Cline CLI |
| [update-codex.sh](../updates/update-codex.sh) | Run native `codex update` for the standalone CLI installed by this project |
| [update-composer.sh](../updates/update-composer.sh) | Self-update the standalone Composer PHAR installed by this project |
| [update-ctop.sh](../updates/update-ctop.sh) | Atomically install the checksum-verified latest ctop release |
| [update-cursor-agent.sh](../updates/update-cursor-agent.sh) | Update the repository-managed Cursor Agent CLI |
| [update-deno.sh](../updates/update-deno.sh) | Upgrade the Deno binary installed under `$DENO_INSTALL` |
| [update-dive.sh](../updates/update-dive.sh) | Install the checksum-verified latest official dive RPM release |
| [update-fisher.sh](../updates/update-fisher.sh) | Update Fisher and its managed Fish plugins |
| [update-flutter.sh](../updates/update-flutter.sh) | Upgrade Flutter on its current release channel |
| [update-gemini.sh](../updates/update-gemini.sh) | Install the latest stable Gemini CLI into its existing global npm prefix |
| [update-github-copilot.sh](../updates/update-github-copilot.sh) | Update the repository-managed GitHub Copilot CLI |
| [update-go.sh](../updates/update-go.sh) | Safely replace the managed SDK with the checksum-verified latest stable Go release |
| [update-goose.sh](../updates/update-goose.sh) | Update the repository-managed goose CLI |
| [update-huggingface-cli.sh](../updates/update-huggingface-cli.sh) | Update the repository-managed Hugging Face CLI |
| [update-lazydocker.sh](../updates/update-lazydocker.sh) | Install the checksum-verified latest lazydocker release |
| [update-llama-cpp.sh](../updates/update-llama-cpp.sh) | Fast-forward a clean llama.cpp checkout and rebuild its existing CMake configuration |
| [update-mcp-inspector.sh](../updates/update-mcp-inspector.sh) | Update the npm-owned MCP Inspector installation |
| [update-mistral-vibe.sh](../updates/update-mistral-vibe.sh) | Upgrade Mistral Vibe through its existing uv tool installation |
| [update-node.sh](../updates/update-node.sh) | Update the official NVM checkout, then install and select the latest Node.js LTS |
| [update-nvim.sh](../updates/update-nvim.sh) | Replace the managed Neovim installation only when an official or configured digest is available |
| [update-oh-my-zsh.sh](../updates/update-oh-my-zsh.sh) | Run Oh My Zsh's automation-safe upgrade script |
| [update-opencode.sh](../updates/update-opencode.sh) | Update the curl-installed opencode CLI through its native updater |
| [update-pipx-tools.sh](../updates/update-pipx-tools.sh) | Upgrade installed Poetry, database CLIs, LLM, and LiteLLM pipx applications |
| [update-pyenv.sh](../updates/update-pyenv.sh) | Fast-forward the clean pyenv checkout |
| [update-rbenv.sh](../updates/update-rbenv.sh) | Fast-forward the clean rbenv and ruby-build checkouts |
| [update-rust.sh](../updates/update-rust.sh) | Update rustup and installed Rust toolchains |
| [update-starship.sh](../updates/update-starship.sh) | Atomically install the checksum-verified latest Starship release asset |
| [update-tpm.sh](../updates/update-tpm.sh) | Fast-forward the clean TPM checkout |
| [update-vscode-extensions.sh](../updates/update-vscode-extensions.sh) | Update extensions through the RPM-owned VS Code CLI |
| [update-vscode.sh](../updates/update-vscode.sh) | Upgrade the Microsoft `code` RPM with a targeted DNF transaction |

The updater set intentionally excludes ordinary DNF-managed packages, applications with their own automatic updater, and tools without a documented, ownership-compatible, verifiable scriptable update path. [`updates/skipped.txt`](../updates/skipped.txt) records the audited reason for every catalogued installer without an updater. Individual updaters skip absent or differently managed installations. Source-checkout updaters refuse dirty working trees rather than overwrite local changes.

## software/

Virtualization stacks.

| Script | Purpose |
|---|---|
| [virtualbox.sh](../software/virtualbox.sh) | VirtualBox + extension pack |
| [boxes.sh](../software/boxes.sh) | GNOME Boxes + virt-manager |
| [vmware.sh](../software/vmware.sh) | Installs kernel build prereqs for VMware Workstation Pro (manual download required) |

## vpn/

VPN clients.

| Script | Purpose |
|---|---|
| [nord.sh](../vpn/nord.sh) | NordVPN official Linux app via `install.sh`; adds user to `nordvpn` group |
| [tailscale.sh](../vpn/tailscale.sh) | Tailscale mesh VPN via the official installer; `$TAILSCALE_AUTHKEY` enables non-interactive `tailscale up` |

## mobile/

Manual utilities — **not** wired into `setup.sh`.

| Script | Purpose |
|---|---|
| [zip_flutter_plugin.sh](../mobile/zip_flutter_plugin.sh) | Archives a Flutter plugin directory excluding build artefacts |
