#!/bin/bash
set -euo pipefail
for pkg in gnome-tweaks ca-certificates; do
    rpm -q "$pkg" >/dev/null
done
for cmd in git curl wget gcc make; do
    cmd_path=$(command -v "$cmd")
    rpm -qf "$cmd_path" >/dev/null
done
git config --global --get user.email | grep -q '@'
