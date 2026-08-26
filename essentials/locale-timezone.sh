#!/bin/bash
set -euo pipefail

# Re-exec under bash if invoked via `sh` (dash mishandles &>, [[ ]], etc.)
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HELPER="$REPO_ROOT/lib/config.bash"
PKG_HELPER="$REPO_ROOT/lib/pkg.bash"
# shellcheck source=lib/config.bash
source "$CONFIG_HELPER" || { echo "❌ Missing config helper: $CONFIG_HELPER" >&2; exit 1; }
# shellcheck source=lib/pkg.bash
source "$PKG_HELPER" || { echo "❌ Missing package helper: $PKG_HELPER" >&2; exit 1; }
load_config "$REPO_ROOT"

echo "🚀 Configuring locale and timezone..."

DESIRED_LOCALE="${LOCALE:-en_US.UTF-8}"
DESIRED_TZ="${TZ:-}"

if ! [[ "$DESIRED_LOCALE" =~ ^[A-Za-z]{2,3}_[A-Za-z0-9@._-]+$ ]]; then
    echo "❌ Invalid locale: $DESIRED_LOCALE" >&2
    exit 1
fi

locale_key() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '.-'
}

locale_available() {
    local candidate desired_key
    desired_key="$(locale_key "$DESIRED_LOCALE")"
    while IFS= read -r candidate; do
        [[ "$(locale_key "$candidate")" == "$desired_key" ]] && return 0
    done < <(locale -a 2>/dev/null)
    return 1
}

# Detect whether systemd is the active init (timedatectl/localectl need it).
HAVE_SYSTEMD=0
[ -d /run/systemd/system ] && HAVE_SYSTEMD=1

# ── Timezone ──────────────────────────────────────────────────────────────────
if [ "$HAVE_SYSTEMD" = "1" ]; then
    CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "")
else
    CURRENT_TZ=$(readlink -f /etc/localtime 2>/dev/null | sed 's|^/usr/share/zoneinfo/||' || echo "")
fi

if [ -z "$DESIRED_TZ" ]; then
    echo "🔍 No TZ configured — auto-detecting from public IP..."
    DESIRED_TZ=$(curl -fsSL --retry 3 --retry-all-errors --max-time 5 \
        https://ipapi.co/timezone 2>/dev/null || echo "")
fi

if [ -z "$DESIRED_TZ" ]; then
    echo "⚠️  Could not determine timezone — leaving current value ($CURRENT_TZ)"
elif [ "$DESIRED_TZ" = "$CURRENT_TZ" ]; then
    echo "✅ Timezone already $CURRENT_TZ"
elif [[ "$DESIRED_TZ" == *..* ]] || ! [[ "$DESIRED_TZ" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]]; then
    echo "❌ Invalid timezone: $DESIRED_TZ" >&2
    exit 1
elif [ ! -f "/usr/share/zoneinfo/$DESIRED_TZ" ]; then
    echo "❌ Unknown timezone: $DESIRED_TZ"
    exit 1
elif [ "$HAVE_SYSTEMD" = "1" ]; then
    echo "🔧 Setting timezone to $DESIRED_TZ..."
    sudo timedatectl set-timezone "$DESIRED_TZ"
    echo "✅ Timezone set"
else
    echo "🔧 Setting timezone to $DESIRED_TZ (no systemd — using /etc/localtime)..."
    sudo ln -sf "/usr/share/zoneinfo/$DESIRED_TZ" /etc/localtime
    if command -v restorecon &>/dev/null; then
        sudo restorecon /etc/localtime
    fi
    echo "✅ Timezone set"
fi

# ── Locale ────────────────────────────────────────────────────────────────────
if locale_available; then
    echo "✅ Locale $DESIRED_LOCALE already available"
else
    LOCALE_LANGUAGE="${DESIRED_LOCALE%%_*}"
    LOCALE_LANGUAGE="${LOCALE_LANGUAGE,,}"
    echo "📦 Installing Fedora language pack glibc-langpack-$LOCALE_LANGUAGE..."
    dnf_install "glibc-langpack-$LOCALE_LANGUAGE"
    if ! locale_available; then
        echo "❌ $DESIRED_LOCALE is still unavailable after installing its language pack" >&2
        exit 1
    fi
fi

if [ "$HAVE_SYSTEMD" = "1" ]; then
    CURRENT_LANG=$(localectl status 2>/dev/null | awk -F= '/LANG=/{print $2}' | head -1 || echo "")
    if [ "$CURRENT_LANG" = "$DESIRED_LOCALE" ]; then
        echo "✅ System locale already $DESIRED_LOCALE"
    else
        echo "🔧 Setting system locale to $DESIRED_LOCALE..."
        sudo localectl set-locale "LANG=$DESIRED_LOCALE"
    fi
else
    echo "🔧 Setting system locale to $DESIRED_LOCALE (no systemd — writing /etc/locale.conf)..."
    echo "LANG=$DESIRED_LOCALE" | sudo tee /etc/locale.conf >/dev/null
    if command -v restorecon &>/dev/null; then
        sudo restorecon /etc/locale.conf
    fi
fi

echo ""
echo "✅ Locale/timezone configured:"
if [ "$HAVE_SYSTEMD" = "1" ]; then
    timedatectl | sed 's/^/   /'
else
    echo "   Timezone: $(readlink -f /etc/localtime 2>/dev/null | sed 's|^/usr/share/zoneinfo/||')"
    echo "   Locale:   $(head -1 /etc/locale.conf 2>/dev/null)"
fi
echo "💡 New shells will pick up the locale; existing ones keep the old LANG."
