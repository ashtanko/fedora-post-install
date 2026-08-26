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

echo "🚀 Installing database CLI clients..."

# Native clients
dnf_install postgresql valkey mariadb sqlite pipx curl gnupg2

# MongoDB publishes mongosh and its database tools in a signed EL9 RPM
# repository for both Fedora target architectures.
MONGO_ARCH=$(rpm_arch)
repo_add mongodb-org-8.0 \
    "https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/${MONGO_ARCH}/" \
    'https://www.mongodb.org/static/pgp/server-8.0.asc' \
    '4B0752C1BCA238C0B4EE14DC41DE058A4E7DCA05'
if dnf_installed mongodb-mongosh && dnf_installed mongodb-database-tools \
    && command -v mongosh &>/dev/null; then
    echo "✅ mongosh already installed"
else
    echo "📦 Installing mongosh + mongodb-database-tools..."
    dnf_install mongodb-mongosh mongodb-database-tools
    echo "✅ mongosh installed"
fi

# Interactive shells via pipx (auto-completion + syntax highlighting)
pipx ensurepath >/dev/null 2>&1 || true

for tool in pgcli mycli litecli; do
    if command -v "$tool" &>/dev/null; then
        echo "✅ $tool already installed"
    else
        echo "📦 Installing $tool via pipx..."
        pipx install "$tool"
    fi
done

echo ""
echo "✅ Database CLI clients installed!"
echo "   psql      - PostgreSQL"
echo "   valkey-cli - Valkey"
echo "   mysql     - MySQL/MariaDB"
echo "   sqlite3   - SQLite"
command -v mongosh &>/dev/null && echo "   mongosh   - MongoDB (+ mongodump/mongorestore)"
echo "   pgcli     - PostgreSQL with autocomplete"
echo "   mycli     - MySQL with autocomplete"
echo "   litecli   - SQLite with autocomplete"
