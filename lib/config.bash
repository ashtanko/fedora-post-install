# shellcheck shell=bash

# Load configuration without exporting config-only values. Precedence is:
# inherited environment > repository .env > ~/.env-fedora-post-install.
load_config() {
    local __fpi_repo_root="${1:?load_config requires the repository root}"
    local __fpi_user_config="${FEDORA_POST_INSTALL_CONFIG:-$HOME/.env-fedora-post-install}"
    local __fpi_repo_config="$__fpi_repo_root/.env"
    local __fpi_name __fpi_declaration
    local -A __fpi_inherited_values=()
    local -A __fpi_inherited_exports=()

    while IFS= read -r __fpi_name; do
        [[ "$__fpi_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
        __fpi_inherited_values["$__fpi_name"]="${!__fpi_name}"
        __fpi_inherited_exports["$__fpi_name"]=1
    done < <(compgen -e)

    # shellcheck source=/dev/null
    [[ -f "$__fpi_user_config" ]] && source "$__fpi_user_config"
    # shellcheck source=/dev/null
    [[ -f "$__fpi_repo_config" ]] && source "$__fpi_repo_config"

    # An `export` in a config file must not leak a secret into child processes.
    while IFS= read -r __fpi_name; do
        __fpi_declaration="$(declare -p "$__fpi_name" 2>/dev/null || true)"
        if [[ "$__fpi_declaration" == "declare -x"* ]] && [[ -z "${__fpi_inherited_exports[$__fpi_name]:-}" ]]; then
            export -n "${__fpi_name?}"
        fi
    done < <(compgen -v)

    for __fpi_name in "${!__fpi_inherited_values[@]}"; do
        printf -v "$__fpi_name" '%s' "${__fpi_inherited_values[$__fpi_name]}"
        export "${__fpi_name?}"
    done
}
