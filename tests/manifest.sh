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
  "apps/bitwarden-cli.sh|yes||command -v bw && bw --version||/usr/local/bin/bw"
  "apps/flameshot.sh|no|||GUI screenshot tool; needs a display server"

  # dev/
  "dev/aws-cli.sh|yes||command -v aws && command -v session-manager-plugin||/usr/local/aws-cli,/usr/local/bin/aws"
  "dev/databases.sh|yes||command -v psql && command -v valkey-cli && command -v sqlite3 && command -v mysql && command -v mongosh|"
  "dev/docker.sh|partial|INSTALL_DOCKER_DESKTOP=no|command -v docker|Docker's systemd daemon cannot start in the container; the Fedora RPM repository and CLI installation are verified"
  "dev/docker-rootless.sh|no|||needs a systemd user session, a subuid/subgid range, and user namespaces; the container test runs as root with no user manager to install the --user unit into"
  "dev/flutter.sh|no|||Flutter SDK and Linux desktop dependencies are large and GUI-focused"
  "dev/go.sh|yes|GO_INSTALL_DIR=/usr/local/go|/usr/local/go/bin/go version||/usr/local/go"
  "dev/java.sh|yes|JAVA_VERSION=25|rpm -q java-25-openjdk-devel && javac -version|"
  "dev/kubernetes.sh|yes||command -v kubectl && command -v helm && command -v k9s && command -v kind && command -v kustomize|"
  "dev/node.sh|yes||FILE||\$HOME/.nvm"
  "dev/python.sh|yes||FILE||\$HOME/.pyenv,\$HOME/.local/share/pipx/venvs/poetry"
  "dev/rust.sh|yes||bash -lc 'command -v rustc && rustc --version'||\$HOME/.cargo,\$HOME/.rustup"
  "dev/terraform.sh|yes||command -v terraform && command -v tflint && command -v tfsec|"
  "dev/dotnet.sh|yes|DOTNET_VERSION=8.0|command -v dotnet && dotnet --list-sdks|"
  "dev/ruby.sh|yes||FILE||\$HOME/.rbenv"
  "dev/gcloud.sh|yes||command -v gcloud && command -v gke-gcloud-auth-plugin && gcloud --version|"
  "dev/azure-cli.sh|yes||command -v az && az version|"
  "dev/podman.sh|partial||command -v podman && command -v podman-compose|rootless execution needs subuid/subgid ranges and user namespaces; the Fedora CLI packages are installed and verified"
  "dev/deno.sh|yes||test -x \$HOME/.deno/bin/deno && \$HOME/.deno/bin/deno --version||\$HOME/.deno"
  "dev/bun.sh|yes||test -x \$HOME/.bun/bin/bun && \$HOME/.bun/bin/bun --version||\$HOME/.bun"
  "dev/php.sh|yes||command -v php && command -v composer|"
  "dev/cpp.sh|yes||command -v cmake && command -v gdb && command -v clang-tidy && command -v valgrind|"

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
  "ai/antigravity.sh|partial||rpm -q antigravity && command -v antigravity >/dev/null|GUI editor RPM needs a display; repository trust and package ownership are covered by ai-regression.sh|/etc/pki/rpm-gpg/RPM-GPG-KEY-antigravity-rpm,/etc/yum.repos.d/antigravity-rpm.repo"
  "ai/claude.sh|yes|CLAUDE_CHANNEL=stable|rpm -q claude-code && command -v claude && claude --version||/etc/pki/rpm-gpg/RPM-GPG-KEY-claude-code,/etc/yum.repos.d/claude-code.repo"
  "ai/cline.sh|yes|CLINE_VERSION=latest|command -v cline && cline --version|"
  "ai/codex.sh|yes||test -x \$HOME/.local/bin/codex && \$HOME/.local/bin/codex --version||\$HOME/.codex/packages/standalone"
  "ai/cursor-agent.sh|yes||test -x \$HOME/.local/bin/cursor-agent && \$HOME/.local/bin/cursor-agent --version||\$HOME/.local/share/cursor-agent"
  "ai/fabric.sh|yes||test -x \$HOME/.local/bin/fabric && \$HOME/.local/bin/fabric --version|"
  "ai/gemini.sh|yes||bash -lc 'command -v gemini'|"
  "ai/github-copilot.sh|yes||test -x \$HOME/.local/bin/copilot && \$HOME/.local/bin/copilot version|"
  "ai/goose.sh|yes||test -x \$HOME/.local/bin/goose && \$HOME/.local/bin/goose --version|"
  "ai/huggingface-cli.sh|yes||test -x \$HOME/.local/bin/hf && \$HOME/.local/bin/hf version||\$HOME/.hf-cli"
  "ai/llama-cpp.sh|no|||CMake build OOMs / takes too long in CI containers; Fedora build dependencies are covered by ai-regression.sh"
  "ai/litellm.sh|yes|LITELLM_VERSION=latest|test -x \$HOME/.local/bin/litellm && \$HOME/.local/bin/litellm --help >/dev/null||\$HOME/.local/share/pipx/venvs/litellm"
  "ai/llm-cli.sh|yes|LLM_VERSION=latest|test -x \$HOME/.local/bin/llm && \$HOME/.local/bin/llm --version||\$HOME/.local/share/pipx/venvs/llm"
  "ai/mcp-inspector.sh|yes|MCP_INSPECTOR_VERSION=latest|command -v mcp-inspector && mcp-inspector --help >/dev/null|"
  "ai/mistral-vibe.sh|yes||test -x \$HOME/.local/bin/vibe && \$HOME/.local/bin/vibe --version||\$HOME/.local/share/uv/tools/mistral-vibe"
  "ai/ollama-models.sh|no|||downloads user-selected large models and requires a running Ollama service"
  "ai/ollama.sh|partial||command -v ollama|systemd service cannot start in the container; architecture, Fedora prerequisites, service handling, and SELinux relabeling are covered by ai-regression.sh"
  "ai/opencode.sh|yes||test -x \$HOME/.opencode/bin/opencode||\$HOME/.opencode"
  "ai/prompt-runner.sh|yes||test -x \$HOME/.local/bin/prompt|"
  "ai/qwen-code.sh|yes||if [ -x \$HOME/.local/bin/qwen ]; then true; else test -x \$HOME/.qwen/bin/qwen; fi||\$HOME/.qwen"

  # updates/ — maintenance commands require an existing host installation and
  # are exercised with offline command stubs by update-scripts-regression.sh.
  "updates/update-aider.sh|no|||requires the user-local Aider installation created by this project; covered by local regression"
  "updates/update-all.sh|no|||runs every supported updater against existing host installations; covered by local regression"
  "updates/update-android-studio.sh|no|||requires the project-managed Android Studio tarball and network access; covered by local regression"
  "updates/update-antigravity.sh|no|||requires the Google RPM-packaged Antigravity installation; covered by local regression"
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
  "software/boxes.sh|no|||needs systemd, KVM, libvirt networking, and a display; covered by software-regression.sh"
  "software/virtualbox.sh|no|||needs bare-metal kernel modules and Secure Boot firmware enrollment; covered by software-regression.sh"
  "software/vmware.sh|no|||needs a manual Broadcom download and bare-metal kernel modules; covered by software-regression.sh"

  # vpn/
  "vpn/nord.sh|no|||needs systemd and a live VPN daemon; Fedora repository, service, and group paths are covered by vpn-regression.sh"
  "vpn/tailscale.sh|no|||needs systemd and tailnet enrollment; Fedora repository, service, and auth-key paths are covered by vpn-regression.sh"

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
