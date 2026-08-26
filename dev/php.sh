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

echo "🚀 Installing PHP + Composer..."

PHP_VERSION="${PHP_VERSION:-}"
BIN_DIR="/usr/local/bin"

# Fedora owns the PHP runtime and extensions as one coherent module stream.
echo "📦 Installing Fedora PHP + common extensions..."
dnf_install \
    php-cli php-common php-mbstring php-xml php-process php-mysqlnd php-pdo php-pecl-zip \
    curl unzip

ACTIVE_PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
if [ -n "$PHP_VERSION" ] && [ "$ACTIVE_PHP_VERSION" != "$PHP_VERSION" ]; then
    echo "❌ PHP_VERSION=$PHP_VERSION was requested, but this Fedora release provides PHP $ACTIVE_PHP_VERSION" >&2
    echo "💡 Fedora-native PHP follows the Fedora release; no third-party PHP repository is enabled." >&2
    exit 1
fi
echo "✅ PHP $ACTIVE_PHP_VERSION installed ($(php -v | head -1))"

# --- Composer (official installer, with its documented signature check —
# same "don't trust an unverified download" posture as the checksum
# verification used for lazygit/k9s/kind/kustomize elsewhere in this repo) ---
if command -v composer &>/dev/null; then
    echo "✅ Composer already installed ($(composer --version 2>/dev/null | head -1))"
else
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    echo "📥 Downloading Composer installer..."
    curl -fsSL --retry 3 --retry-all-errors -o "$TMP/composer-setup.php" https://getcomposer.org/installer

    echo "🔒 Verifying installer signature..."
    EXPECTED_SIG=$(curl -fsSL --retry 3 --retry-all-errors https://composer.github.io/installer.sig)
    ACTUAL_SIG=$(php -r "echo hash_file('sha384', '$TMP/composer-setup.php');")
    if [ "$EXPECTED_SIG" != "$ACTUAL_SIG" ]; then
        echo "❌ Composer installer signature mismatch — refusing to run it"
        exit 1
    fi
    echo "✅ Signature verified"

    php "$TMP/composer-setup.php" --quiet --install-dir="$TMP" --filename=composer
    sudo install -m 0755 "$TMP/composer" "$BIN_DIR/composer"
    echo "✅ Composer installed → $BIN_DIR/composer"
fi

echo ""
echo "✅ PHP toolchain ready!"
echo "   $(php -v | head -1)"
echo "   $(composer --version 2>/dev/null | head -1)"
echo "💡 PHP_VERSION may be set to assert the Fedora-provided major.minor version"
