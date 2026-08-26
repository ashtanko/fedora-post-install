# shellcheck shell=bash

_pkg_error() {
    echo "❌ $*" >&2
}

_pkg_require_command() {
    local command_name="${1:?command name required}"
    if ! command -v "$command_name" &>/dev/null; then
        _pkg_error "Required command is not available: $command_name"
        return 1
    fi
}

dnf_major() {
    local version_output first_line major

    _pkg_require_command dnf || return 1
    version_output="$(dnf --version 2>&1)" || {
        _pkg_error "Could not determine the installed DNF version"
        return 1
    }
    first_line="${version_output%%$'\n'*}"

    if [[ "$first_line" =~ dnf5[[:space:]]+version[[:space:]]+([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
    elif [[ "$first_line" =~ ^([0-9]+)\. ]]; then
        major="${BASH_REMATCH[1]}"
    else
        _pkg_error "Unrecognized DNF version output: $first_line"
        return 1
    fi

    case "$major" in
        4|5) printf '%s\n' "$major" ;;
        *)
            _pkg_error "Unsupported DNF major version: $major"
            return 1
            ;;
    esac
}

dnf_installed() {
    local package="${1:?dnf_installed requires a package name}"
    _pkg_require_command rpm || return 1
    rpm -q --quiet "$package"
}

dnf_install() {
    local package
    local -a missing=()

    if (( $# == 0 )); then
        _pkg_error "dnf_install requires at least one package"
        return 2
    fi

    for package in "$@"; do
        if ! dnf_installed "$package"; then
            missing+=("$package")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        return 0
    fi

    _pkg_require_command dnf || return 1
    sudo dnf -q install -y --setopt=install_weak_deps=False "${missing[@]}"
}

dnf_group_install() {
    local group="${1:?dnf_group_install requires a group name}"
    local major

    major="$(dnf_major)" || return 1
    if [[ "$major" == 5 ]]; then
        sudo dnf -q group install -y --setopt=install_weak_deps=False "$group"
    else
        # DNF4 supports the historical groupinstall alias; DNF5 removed it.
        sudo dnf -q groupinstall -y --setopt=install_weak_deps=False "$group"
    fi
}

_pkg_key_fingerprints() {
    local key_file="${1:?key file required}"

    gpg --batch --quiet --with-colons --show-keys "$key_file" 2>/dev/null \
        | awk -F: '
            $1 == "pub" { want_primary_fingerprint = 1; next }
            want_primary_fingerprint && $1 == "fpr" {
                print toupper($10)
                want_primary_fingerprint = 0
            }
        '
}

_pkg_key_matches() {
    local key_file="${1:?key file required}"
    local expected="${2:?expected fingerprint required}"
    local -a fingerprints=()

    mapfile -t fingerprints < <(_pkg_key_fingerprints "$key_file")
    [[ ${#fingerprints[@]} -eq 1 && "${fingerprints[0]}" == "$expected" ]]
}

repo_add() (
    local name="${1:?repo_add requires a repository name}"
    local baseurl="${2:?repo_add requires a base URL}"
    local gpgkey_url="${3:?repo_add requires a GPG key URL}"
    local expected_fingerprint="${4:?repo_add requires a GPG fingerprint}"
    local repo_gpgcheck="${5:-1}"
    local repo_dir="/etc/yum.repos.d"
    local key_dir="/etc/pki/rpm-gpg"
    local repo_file key_file actual_fingerprint
    local TMP_KEY TMP_REPO

    if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        _pkg_error "Invalid repository name: $name"
        return 2
    fi
    if [[ "$baseurl" != https://* || "$baseurl" == *$'\n'* || "$baseurl" == *$'\r'* ]]; then
        _pkg_error "Repository base URL must be a single HTTPS URL"
        return 2
    fi
    if [[ "$gpgkey_url" != https://* || "$gpgkey_url" == *$'\n'* || "$gpgkey_url" == *$'\r'* ]]; then
        _pkg_error "Repository GPG key URL must be a single HTTPS URL"
        return 2
    fi
    if [[ "$repo_gpgcheck" != 0 && "$repo_gpgcheck" != 1 ]]; then
        _pkg_error "Repository metadata GPG checking must be 0 or 1"
        return 2
    fi

    expected_fingerprint="${expected_fingerprint//[[:space:]]/}"
    expected_fingerprint="${expected_fingerprint//:/}"
    expected_fingerprint="${expected_fingerprint^^}"
    if ! [[ "$expected_fingerprint" =~ ^([0-9A-F]{40}|[0-9A-F]{64})$ ]]; then
        _pkg_error "Repository GPG fingerprint must contain 40 or 64 hexadecimal characters"
        return 2
    fi

    _pkg_require_command curl || return 1
    _pkg_require_command gpg || return 1
    _pkg_require_command rpm || return 1

    repo_file="$repo_dir/$name.repo"
    key_file="$key_dir/RPM-GPG-KEY-$name"
    TMP_KEY="$(mktemp)"
    TMP_REPO="$(mktemp)"
    trap 'rm -f "$TMP_KEY" "$TMP_REPO"' EXIT

    cat >"$TMP_REPO" <<EOF
[$name]
name=$name
baseurl=$baseurl
enabled=1
gpgcheck=1
repo_gpgcheck=$repo_gpgcheck
gpgkey=file://$key_file
EOF

    if [[ -r "$repo_file" && -r "$key_file" ]] \
        && cmp -s "$TMP_REPO" "$repo_file" \
        && _pkg_key_matches "$key_file" "$expected_fingerprint"; then
        return 0
    fi

    curl -fsSL --retry 3 --retry-all-errors -o "$TMP_KEY" "$gpgkey_url"
    if ! _pkg_key_matches "$TMP_KEY" "$expected_fingerprint"; then
        actual_fingerprint="$(_pkg_key_fingerprints "$TMP_KEY" | paste -sd, -)"
        _pkg_error "GPG fingerprint mismatch for $name (expected $expected_fingerprint, got ${actual_fingerprint:-none})"
        return 1
    fi

    sudo install -d -m 0755 "$repo_dir" "$key_dir"
    sudo install -m 0644 "$TMP_KEY" "$key_file"
    sudo rpm --import "$key_file"
    sudo install -m 0644 "$TMP_REPO" "$repo_file"

    if command -v restorecon &>/dev/null; then
        sudo restorecon "$key_file" "$repo_file"
    fi
)

copr_enable() {
    local project="${1:?copr_enable requires owner/project}"

    if ! [[ "$project" =~ ^@?[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
        _pkg_error "Invalid COPR project: $project"
        return 2
    fi

    dnf_install dnf-plugins-core
    sudo dnf -q copr enable -y "$project"
}

flatpak_install() {
    local app_id="${1:?flatpak_install requires an application ID}"

    if ! [[ "$app_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]+$ ]]; then
        _pkg_error "Invalid Flatpak application ID: $app_id"
        return 2
    fi

    if ! command -v flatpak &>/dev/null; then
        dnf_install flatpak
    fi
    _pkg_require_command flatpak || return 1

    if flatpak info --user "$app_id" &>/dev/null; then
        return 0
    fi

    flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub "$app_id"
}

rpm_arch() {
    local arch

    _pkg_require_command rpm || return 1
    arch="$(rpm --eval '%{_arch}')"
    case "$arch" in
        x86_64|amd64) printf '%s\n' x86_64 ;;
        aarch64|arm64) printf '%s\n' aarch64 ;;
        *)
            _pkg_error "Unsupported RPM architecture: $arch"
            return 1
            ;;
    esac
}

release_arch() {
    local arch

    arch="$(rpm_arch)" || return 1
    case "$arch" in
        x86_64) printf '%s\n' amd64 ;;
        aarch64) printf '%s\n' arm64 ;;
    esac
}
