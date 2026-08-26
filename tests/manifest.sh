# shellcheck shell=bash
# Single source of truth for which scripts are tested in Docker and how.
#
# Format: "path|compat|env_vars|verify_cmd|skip_reason|state_paths"
#   compat     : yes | no | partial
#   env_vars   : comma-separated KEY=VAL pairs (passed via `env` to the script)
#   verify_cmd : shell snippet asserting installation succeeded (empty = no verify)
#   skip_reason: required when compat=no, ignored otherwise
#   state_paths: optional comma-separated absolute paths to include in snapshots;
#                literal $HOME is expanded without evaluating shell code
#
# When verify_cmd is "FILE", run-script.sh looks for tests/verify/<dir>_<base>.sh
# instead. Use that for multi-line verifications.

SCRIPTS=(
  # essentials/
  "essentials/auto-updates.sh|no|||the DNF automatic timer needs systemd as PID 1"
  "essentials/firewall.sh|no|||firewalld needs systemd and kernel netfilter; rules don't apply inside a container"
  "essentials/fstrim.sh|no|||no systemd in a plain container to manage fstrim.timer; ROTA detection works but has nothing to enable"
  "essentials/gnome-settings.sh|no|||requires active GNOME session (gsettings/dbus)"
  "essentials/journald.sh|no|||no systemd-journald in a plain container; the drop-in would never take effect"
  "essentials/locale-timezone.sh|partial|TZ=Etc/UTC,LOCALE=en_US.UTF-8|[[ \$(locale -a) == *en_US.utf8* ]]|timedatectl needs systemd; the Fedora language-pack path still runs"
  "essentials/swap.sh|no|||needs real block device + /etc/fstab persistence"
  "essentials/sysctl-limits.sh|partial||grep -q 'fs.inotify.max_user_watches=524288' /etc/sysctl.d/99-fpi-inotify.conf \&\& grep -q 'soft nofile 1048576' /etc/security/limits.d/99-fpi-nofile.conf|/proc/sys is read-only in an unprivileged container; sysctl -p no-ops but the drop-in files still land and are verified|/etc/sysctl.d/99-fpi-inotify.conf,/etc/security/limits.d/99-fpi-nofile.conf"
  "essentials/system-info.sh|yes||ls \$HOME/system-info-*.log >/dev/null|"
  "essentials/fail2ban.sh|partial||grep -q 'backend  = systemd' /etc/fail2ban/jail.d/99-fpi-sshd.local \&\& grep -q 'maxretry = 5' /etc/fail2ban/jail.d/99-fpi-sshd.local|no systemd to start the fail2ban service; the Fedora jail.d drop-in still lands and is verified|/etc/fail2ban/jail.d/99-fpi-sshd.local"
  "essentials/lynis.sh|yes||ls \$HOME/lynis-audit-*.log >/dev/null|"

  # system/
  "system/base.sh|yes|GIT_NAME=CI Tester,GIT_EMAIL=ci@example.com|FILE||\$HOME/.gitconfig"
  "system/gpg.sh|partial|GIT_NAME=CI Tester,GIT_EMAIL=ci@example.com|[[ \$(gpg --list-secret-keys) == *ci@example.com* ]]|entropy slow; key generated but git signing config skipped if no rc|\$HOME/.gnupg,\$HOME/.gitconfig"
  "system/hostname.sh|no|||hostnamectl/UTS namespace changes aren't meaningful inside a container"
  "system/hosts-dns.sh|no|||Fedora containers have neither an active NetworkManager connection nor systemd-resolved"
  "system/keyboard.sh|no|||keyd daemon needs /dev/uinput + systemd"
  "system/ntp.sh|partial||rpm -q chrony &>/dev/null|chronyd cannot be started without systemd as PID 1; package installation is still verified"
  "system/ssh.sh|partial|GIT_EMAIL=ci@example.com|test -f \$HOME/.ssh/id_ed25519|may prompt for passphrase if interactive|\$HOME/.ssh"
  "system/sudoers.sh|yes|SUDO_TIMESTAMP_TIMEOUT_MINUTES=15|sudo grep -q 'timestamp_timeout=15' /etc/sudoers.d/99-fpi-timeout|"
  "system/user-groups.sh|yes||grep -qw wheel <(sudo -u \$(id -un) id -nG) && grep -qw dialout <(sudo -u \$(id -un) id -nG)|"

  # apps/
  "apps/browsers.sh|no|||Chrome installs but is GUI-only; not useful in CI"
  "apps/guake.sh|no|||GUI terminal emulator"
  "apps/postman.sh|no|||Postman is a GUI app; needs display"
  "apps/vscode.sh|no|||GUI editor; pulls hundreds of MB for no test value"
  "apps/warp.sh|no|||GUI terminal"
  "apps/bitwarden-cli.sh|no|||the Phase 5 container harness is not Fedora yet; architecture and installation policy are covered by apps-regression.sh"
  "apps/flameshot.sh|no|||GUI screenshot tool; needs a display server"

  # dev/
  "dev/aws-cli.sh|no|||the Phase 5 container harness is not Fedora yet; signatures and architecture policy are covered by dev-regression.sh"
  "dev/databases.sh|no|||requires Fedora packages plus MongoDB's RPM repository; mappings are covered by dev-regression.sh"
  "dev/docker.sh|no|||requires Docker's Fedora RPM repository and a systemd daemon; policy is covered by dev-regression.sh"
  "dev/docker-rootless.sh|no|||needs a systemd user session, a subuid/subgid range, and user namespaces; the container test runs as root with no user manager to install the --user unit into"
  "dev/flutter.sh|no|||Flutter SDK and Linux desktop dependencies are large and GUI-focused"
  "dev/go.sh|no|||the Phase 5 container harness is not Fedora yet; verified archive behavior remains covered by runtime regressions"
  "dev/java.sh|no|||uses Fedora OpenJDK packages; version-to-package mapping is covered by dev-regression.sh"
  "dev/kubernetes.sh|no|||uses a Fedora RPM repository and several release downloads; trust policy is covered by dev-regression.sh"
  "dev/node.sh|no|||now requires Fedora-managed prerequisites before the user-local NVM install"
  "dev/python.sh|no|||uses Fedora development groups and build dependency package names"
  "dev/rust.sh|no|||now requires Fedora-managed curl before the user-local rustup install"
  "dev/terraform.sh|no|||uses HashiCorp's Fedora RPM repository plus verified release assets; trust policy is covered by dev-regression.sh"
  "dev/dotnet.sh|no|||uses Fedora-native dotnet-sdk packages"
  "dev/ruby.sh|no|||uses Fedora development groups and ruby-build dependency package names"
  "dev/gcloud.sh|no|||uses Google's architecture-specific RPM repository; trust policy is covered by dev-regression.sh"
  "dev/azure-cli.sh|no|||uses Microsoft's EL9 RPM repository; trust policy is covered by dev-regression.sh"
  "dev/podman.sh|no|||uses Fedora-native Podman, rootless, compose, and SELinux packages"
  "dev/deno.sh|no|||now requires Fedora-managed prerequisites before the user-local Deno install"
  "dev/bun.sh|no|||now requires Fedora-managed prerequisites before the user-local Bun install"
  "dev/php.sh|no|||uses Fedora-native PHP packages and extensions"
  "dev/cpp.sh|no|||uses Fedora's development-tools group and native compiler packages"

  # tools/
  "tools/backup-home.sh|no|||interactive backup utility; not a setup script"
  "tools/btop.sh|yes||FILE|"
  "tools/cli-tools.sh|yes||FILE|"
  "tools/fonts.sh|yes||test -n \"\$(find \$HOME/.local/share/fonts -type f -print -quit 2>/dev/null)\"||\$HOME/.local/share/fonts"
  "tools/fish.sh|yes|SET_FISH_AS_DEFAULT=no|FILE||\$HOME/.config/fish"
  "tools/git-config.sh|yes|GIT_NAME=CI Tester,GIT_EMAIL=ci@example.com|git config --global --get pull.rebase||\$HOME/.gitconfig,\$HOME/.config/git"
  "tools/modern-cli.sh|yes||FILE|"
  "tools/pre-commit-setup.sh|yes||bash -lc 'command -v pre-commit'||\$HOME/.config/pre-commit,\$HOME/.config/git/template"
  "tools/starship.sh|yes||FILE||\$HOME/.config/fish"
  "tools/system-maintenance.sh|partial||command -v dnf|journalctl/flatpak may be absent; available Fedora maintenance steps still run"
  "tools/zsh.sh|yes|INSTALL_OH_MY_ZSH=no|command -v zsh||\$HOME/.oh-my-zsh"
  "tools/wireshark.sh|partial||command -v tshark && getent group wireshark && test -n \"\$(getcap /usr/bin/dumpcap)\"|there is no real capture interface in a container, but the group and dumpcap capabilities are verified"
  "tools/dotfiles.sh|yes||command -v chezmoi && chezmoi --version|"
  "tools/rclone.sh|yes||command -v rclone && rclone version|"
  "tools/lazydocker.sh|yes||command -v lazydocker && lazydocker --version|"
  "tools/ctop.sh|yes||command -v ctop && ctop -v|"
  "tools/dive.sh|yes||command -v dive && dive --version|"
  "tools/hadolint.sh|yes||command -v hadolint && hadolint --version|"
  "tools/trivy.sh|yes||command -v trivy && trivy --version|"
  "tools/docker-maintenance.sh|partial||bash tools/docker-maintenance.sh >/dev/null|no reachable Docker daemon in a container, so only the guard path runs; re-running it is the verification that the guard exits cleanly"
  "tools/tmux-config.sh|yes||FILE||\$HOME/.tmux.conf,\$HOME/.tmux/plugins/tpm"
  "tools/restic.sh|yes||command -v restic && restic version|"
  "tools/network-tools.sh|yes||command -v mtr && command -v nmap && command -v dig && command -v iperf3 && command -v http|"
  "tools/gitleaks.sh|yes||command -v gitleaks && gitleaks version|"
  "tools/yq.sh|yes||command -v yq && yq --version|"
  "tools/just.sh|yes||command -v just && just --version|"
  "tools/atuin.sh|yes||test -x \$HOME/.local/bin/atuin && \$HOME/.local/bin/atuin --version||\$HOME/.local/bin/atuin"

  # ide/
  "ide/jetbrains-toolbox.sh|no|||checksum-verified GUI archive is large and needs a display"
  "ide/nvim.sh|yes||command -v nvim && rpm -q neovim &>/dev/null||\$HOME/.config/nvim"
  "ide/vscode-extensions.sh|no|||requires VS Code installed + display"
  "ide/zed.sh|no|||GUI editor"
  "ide/android-studio.sh|no|||checksum-verified official archive is about 1.6 GB and the IDE needs a display"
  "ide/cursor.sh|no|||vendor RPM is a large GUI editor and needs a display"
  "ide/dbeaver.sh|no|||Flathub GUI database client needs a display"

  # ai/
  "ai/aider.sh|yes||test -x \$HOME/.local/bin/aider && \$HOME/.local/bin/aider --version|"
  "ai/antigravity.sh|partial||command -v antigravity >/dev/null|GUI editor package; the APT repo wiring and package install are verified but the app itself needs a display|/etc/apt/keyrings/antigravity-repo-key.gpg,/etc/apt/sources.list.d/antigravity.list"
  "ai/claude.sh|yes|CLAUDE_CHANNEL=stable|command -v claude && claude --version||/etc/apt/keyrings/claude-code.asc,/etc/apt/sources.list.d/claude-code.list"
  "ai/cline.sh|yes|CLINE_VERSION=latest|command -v cline && cline --version|"
  "ai/codex.sh|yes||test -x \$HOME/.local/bin/codex && \$HOME/.local/bin/codex --version||\$HOME/.codex/packages/standalone"
  "ai/cursor-agent.sh|yes||test -x \$HOME/.local/bin/cursor-agent && \$HOME/.local/bin/cursor-agent --version||\$HOME/.local/share/cursor-agent"
  "ai/fabric.sh|yes||test -x \$HOME/.local/bin/fabric && \$HOME/.local/bin/fabric --version|"
  "ai/gemini.sh|yes||bash -lc 'command -v gemini'|"
  "ai/github-copilot.sh|yes||test -x \$HOME/.local/bin/copilot && \$HOME/.local/bin/copilot version|"
  "ai/goose.sh|yes||test -x \$HOME/.local/bin/goose && \$HOME/.local/bin/goose --version|"
  "ai/huggingface-cli.sh|yes||test -x \$HOME/.local/bin/hf && \$HOME/.local/bin/hf version||\$HOME/.hf-cli"
  "ai/llama-cpp.sh|no|||CMake build OOMs / takes too long in CI containers; verify on real hardware"
  "ai/litellm.sh|yes|LITELLM_VERSION=latest|test -x \$HOME/.local/bin/litellm && \$HOME/.local/bin/litellm --help >/dev/null||\$HOME/.local/share/pipx/venvs/litellm"
  "ai/llm-cli.sh|yes|LLM_VERSION=latest|test -x \$HOME/.local/bin/llm && \$HOME/.local/bin/llm --version||\$HOME/.local/share/pipx/venvs/llm"
  "ai/mcp-inspector.sh|yes|MCP_INSPECTOR_VERSION=latest|command -v mcp-inspector && mcp-inspector --help >/dev/null|"
  "ai/mistral-vibe.sh|yes||test -x \$HOME/.local/bin/vibe && \$HOME/.local/bin/vibe --version||\$HOME/.local/share/uv/tools/mistral-vibe"
  "ai/ollama-models.sh|no|||downloads user-selected large models and requires a running Ollama service"
  "ai/ollama.sh|partial||command -v ollama|systemd service won't start; binary installs"
  "ai/opencode.sh|yes||test -x \$HOME/.opencode/bin/opencode||\$HOME/.opencode"
  "ai/prompt-runner.sh|yes||test -x \$HOME/.local/bin/prompt|"
  "ai/qwen-code.sh|yes||if [ -x \$HOME/.local/bin/qwen ]; then true; else test -x \$HOME/.qwen/bin/qwen; fi||\$HOME/.qwen"

  # updates/ — maintenance commands require an existing host installation and
  # are exercised with offline command stubs by update-scripts-regression.sh.
  "updates/update-aider.sh|no|||requires the user-local Aider installation created by this project; covered by local regression"
  "updates/update-all.sh|no|||runs every supported updater against existing host installations; covered by local regression"
  "updates/update-android-studio.sh|no|||requires the project-managed Android Studio tarball and network access; covered by local regression"
  "updates/update-antigravity.sh|no|||requires the Google APT-packaged Antigravity installation; covered by local regression"
  "updates/update-atuin.sh|no|||requires the user-local Atuin installation and network access; covered by local regression"
  "updates/update-aws-cli.sh|no|||requires the standalone AWS CLI v2 installation and network access; covered by local regression"
  "updates/update-bun.sh|no|||requires an existing Bun installation; covered by local regression"
  "updates/update-claude.sh|no|||requires an existing Claude Code installation; covered by local regression"
  "updates/update-cline.sh|no|||requires the npm-owned Cline CLI installation; covered by local regression"
  "updates/update-codex.sh|no|||requires an existing standalone Codex installation with native updater support; covered by local regression"
  "updates/update-composer.sh|no|||requires the standalone Composer PHAR installed by this project; covered by local regression"
  "updates/update-ctop.sh|no|||requires the standalone ctop binary installed by this project; covered by local regression"
  "updates/update-cursor-agent.sh|no|||requires the user-local Cursor Agent installation created by this project; covered by local regression"
  "updates/update-deno.sh|no|||requires an existing Deno installation; covered by local regression"
  "updates/update-dive.sh|no|||requires the release-package dive installation created by this project; covered by local regression"
  "updates/update-fisher.sh|no|||requires an existing Fish and Fisher installation; covered by local regression"
  "updates/update-flutter.sh|no|||requires an existing Flutter SDK checkout; covered by local regression"
  "updates/update-gemini.sh|no|||requires an existing Gemini CLI and its owning npm prefix; covered by local regression"
  "updates/update-github-copilot.sh|no|||requires the user-local GitHub Copilot CLI installation; covered by local regression"
  "updates/update-go.sh|no|||requires an existing Go SDK and network access; covered by local regression"
  "updates/update-goose.sh|no|||requires the user-local goose installation created by this project; covered by local regression"
  "updates/update-huggingface-cli.sh|no|||requires the standalone Hugging Face CLI installation; covered by local regression"
  "updates/update-lazydocker.sh|no|||requires the standalone lazydocker binary installed by this project; covered by local regression"
  "updates/update-llama-cpp.sh|no|||requires an existing clean llama.cpp checkout and CMake build; covered by local regression"
  "updates/update-mcp-inspector.sh|no|||requires the npm-owned MCP Inspector installation; covered by local regression"
  "updates/update-mistral-vibe.sh|no|||requires the uv-managed Mistral Vibe installation; covered by local regression"
  "updates/update-node.sh|no|||requires an existing NVM installation and network access; covered by local regression"
  "updates/update-oh-my-zsh.sh|no|||requires an existing Oh My Zsh checkout; covered by local regression"
  "updates/update-opencode.sh|no|||requires the curl-installed opencode CLI; covered by local regression"
  "updates/update-pipx-tools.sh|no|||requires one or more project-managed pipx applications; covered by local regression"
  "updates/update-pyenv.sh|no|||requires an existing clean pyenv checkout; covered by local regression"
  "updates/update-rbenv.sh|no|||requires existing clean rbenv and ruby-build checkouts; covered by local regression"
  "updates/update-rust.sh|no|||requires an existing rustup-managed Rust installation; covered by local regression"
  "updates/update-starship.sh|no|||requires the user-local Starship installation and network access; covered by local regression"
  "updates/update-tpm.sh|no|||requires an existing clean TPM checkout; covered by local regression"
  "updates/update-vscode-extensions.sh|no|||requires the RPM-owned VS Code CLI and installed extensions; covered by local regression"
  "updates/update-vscode.sh|no|||requires the Microsoft RPM-packaged VS Code installation; covered by local regression"

  # software/
  "software/boxes.sh|no|||GNOME Boxes needs KVM + display"
  "software/virtualbox.sh|no|||needs kernel modules + bare metal"
  "software/vmware.sh|no|||VMware Workstation needs manual download + kernel build"

  # vpn/
  "vpn/nord.sh|no|||installer invokes systemctl to enable nordvpnd; daemon won't start in container — verify on real hardware"
  "vpn/tailscale.sh|no|||installer invokes systemctl to enable tailscaled; daemon won't start in container — verify on real hardware"

  # mobile/
  "mobile/zip_flutter_plugin.sh|no|||manual Fedora archive utility; covered by mobile-regression.sh"

  # root/
  "setup.sh|no|||interactive menu orchestrator; covered by local regression tests rather than Docker"
  "install.sh|no|||remote installer; downloads release tarball, not exercised in container tests"
)

# ---- Helpers ---------------------------------------------------------------

# Iterate manifest entries, calling: $1 path compat env_vars verify_cmd skip_reason state_paths
manifest_iter() {
    local cb="$1" entry path compat env_vars verify_cmd skip_reason state_paths
    for entry in "${SCRIPTS[@]}"; do
        IFS='|' read -r path compat env_vars verify_cmd skip_reason state_paths <<<"$entry"
        "$cb" "$path" "$compat" "$env_vars" "$verify_cmd" "$skip_reason" "$state_paths"
    done
}

# Lookup helpers (return field for given path; exit 1 if not found)
manifest_lookup() {
    local path="$1" field="$2" entry p c e v r s
    for entry in "${SCRIPTS[@]}"; do
        IFS='|' read -r p c e v r s <<<"$entry"
        if [ "$p" = "$path" ]; then
            case "$field" in
                compat) printf '%s\n' "$c" ;;
                env)    printf '%s\n' "$e" ;;
                verify) printf '%s\n' "$v" ;;
                reason) printf '%s\n' "$r" ;;
                state)  printf '%s\n' "$s" ;;
            esac
            return 0
        fi
    done
    return 1
}

manifest_paths() {
    local entry p _rest
    for entry in "${SCRIPTS[@]}"; do
        IFS='|' read -r p _rest <<<"$entry"
        printf '%s\n' "$p"
    done
}
