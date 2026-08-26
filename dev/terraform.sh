#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
# shellcheck source=lib/config.bash
source "$CONFIG_HELPER" || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
load_config "$REPO_ROOT"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
# shellcheck source=lib/pkg.bash
source "$PKG_HELPER" || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
GITHUB_HELPER="$REPO_ROOT/lib/github.bash"
# shellcheck source=lib/github.bash
source "$GITHUB_HELPER" || { echo "❌ Missing github helper: $GITHUB_HELPER" >&2; exit 1; }

echo "🚀 Installing Terraform + tflint + tfsec..."

ARCH=$(release_arch)
BIN_DIR="/usr/local/bin"

dnf_install curl wget unzip gnupg2

# --- Terraform (HashiCorp Fedora RPM repo) ---
repo_add hashicorp \
    "https://rpm.releases.hashicorp.com/fedora/\$releasever/\$basearch/stable" \
    'https://rpm.releases.hashicorp.com/gpg' \
    '798AEC654E5C15428C8E42EEAA16FCBCA621E701'
if dnf_installed terraform && command -v terraform &>/dev/null; then
    echo "✅ terraform already installed ($(terraform version | head -1))"
else
    echo "📦 Installing terraform..."
    dnf_install terraform
    echo "✅ terraform installed ($(terraform version | head -1))"
fi

# --- tflint (GitHub release; checksum-verified zip) ---
# Deliberately not upstream's `curl .../master/install_linux.sh | sudo bash`:
# that pipes a mutable branch URL straight into root. Resolving the release tag
# and verifying the published digest matches how tools/just.sh, tools/yq.sh, and
# tools/lazydocker.sh install their binaries.
if command -v tflint &>/dev/null; then
    echo "✅ tflint already installed ($(tflint --version | head -1))"
else
    echo "🔍 Resolving latest tflint release..."
    TFLINT_VERSION=$(latest_github_tag terraform-linters/tflint)
    case "$ARCH" in
        amd64|arm64) TFLINT_ARCH="$ARCH" ;;
        *) echo "❌ Unsupported architecture for tflint: $ARCH"; exit 1 ;;
    esac
    TFLINT_ASSET="tflint_linux_${TFLINT_ARCH}.zip"
    TFLINT_BASE="https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}"

    echo "📦 Downloading tflint $TFLINT_VERSION..."
    TMP_TFLINT=$(mktemp -d)
    trap 'rm -rf "$TMP_TFLINT"' EXIT
    wget --tries=3 --waitretry=2 -nv --show-progress \
        -O "$TMP_TFLINT/$TFLINT_ASSET" "${TFLINT_BASE}/${TFLINT_ASSET}"

    echo "🔒 Verifying checksum..."
    curl -fsSL --retry 3 --retry-all-errors -o "$TMP_TFLINT/checksums.txt" "${TFLINT_BASE}/checksums.txt"
    EXPECTED_SHA=$(awk -v want="$TFLINT_ASSET" '$2 == want {print $1; exit}' "$TMP_TFLINT/checksums.txt")
    [[ "$EXPECTED_SHA" =~ ^[0-9a-fA-F]{64}$ ]] \
        || { echo "❌ tflint checksum manifest is missing a valid digest for $TFLINT_ASSET"; exit 1; }
    echo "$EXPECTED_SHA  $TMP_TFLINT/$TFLINT_ASSET" | sha256sum --check --quiet
    echo "✅ Checksum verified"

    unzip -q -o "$TMP_TFLINT/$TFLINT_ASSET" -d "$TMP_TFLINT"
    [ -f "$TMP_TFLINT/tflint" ] || { echo "❌ tflint binary not found in the release zip"; exit 1; }
    sudo install -m 0755 "$TMP_TFLINT/tflint" "$BIN_DIR/tflint"
    rm -rf "$TMP_TFLINT"
    echo "✅ tflint installed → $BIN_DIR/tflint ($(tflint --version | head -1))"
fi

# --- tfsec (GitHub release; signature-verified single binary) ---
if command -v tfsec &>/dev/null; then
    echo "✅ tfsec already installed ($(tfsec --version))"
else
    echo "🔍 Resolving latest tfsec release..."
    TFSEC_VERSION=$(latest_github_tag aquasecurity/tfsec)
    case "$ARCH" in
        amd64) TFSEC_ARCH="amd64" ;;
        arm64) TFSEC_ARCH="arm64" ;;
        *) echo "❌ Unsupported architecture for tfsec: $ARCH"; exit 1 ;;
    esac
    TFSEC_ASSET="tfsec-linux-${TFSEC_ARCH}"
    TFSEC_URL="https://github.com/aquasecurity/tfsec/releases/download/${TFSEC_VERSION}/${TFSEC_ASSET}"
    TFSEC_KEY_FINGERPRINT="D66B222A3EA4C25D5D1A097FC34ACEFB46EC39CE"
    echo "📦 Downloading tfsec $TFSEC_VERSION..."
    TMP_TFSEC=$(mktemp -d)
    trap 'rm -rf "$TMP_TFSEC"' EXIT
    TFSEC_BIN="$TMP_TFSEC/$TFSEC_ASSET"
    TFSEC_SIG="$TFSEC_BIN.${TFSEC_KEY_FINGERPRINT}.sig"
    TFSEC_KEY="$TMP_TFSEC/tfsec-signing-key.asc"
    TFSEC_GNUPGHOME="$TMP_TFSEC/gnupg"
    mkdir -m 700 "$TFSEC_GNUPGHOME"
    wget --tries=3 --waitretry=2 -nv --show-progress -O "$TFSEC_BIN" "$TFSEC_URL"
    curl -fsSL --retry 3 --retry-all-errors -o "$TFSEC_SIG" \
        "${TFSEC_URL}.${TFSEC_KEY_FINGERPRINT}.sig"
    cat >"$TFSEC_KEY" <<'TFSEC_PUBLIC_KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
nX5QmAEwF/nBYV3Du7TIvHtz91yL8A==
=opqY
-----END PGP PUBLIC KEY BLOCK-----
TFSEC_PUBLIC_KEY
    gpg --batch --homedir "$TFSEC_GNUPGHOME" --import "$TFSEC_KEY"
    IMPORTED_FINGERPRINT=$(gpg --batch --homedir "$TFSEC_GNUPGHOME" --with-colons --fingerprint \
        | awk -F: '$1 == "fpr" { print toupper($10); exit }' | tr -d '[:space:]')
    if [ "$IMPORTED_FINGERPRINT" != "$TFSEC_KEY_FINGERPRINT" ]; then
        echo "❌ tfsec signing key fingerprint mismatch: $IMPORTED_FINGERPRINT" >&2
        exit 1
    fi
    gpg --batch --homedir "$TFSEC_GNUPGHOME" --verify "$TFSEC_SIG" "$TFSEC_BIN"
    sudo install -m 0755 "$TFSEC_BIN" "$BIN_DIR/tfsec"
    echo "✅ tfsec installed → $BIN_DIR/tfsec"
fi

echo ""
echo "✅ Terraform toolchain installed!"
echo "   terraform - core IaC engine"
echo "   tflint    - linter"
echo "   tfsec     - static security scanner"
