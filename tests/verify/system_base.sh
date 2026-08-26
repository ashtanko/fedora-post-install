#!/bin/bash
set -euo pipefail
for pkg in gnome-tweaks git curl wget ca-certificates; do
    rpm -q "$pkg" >/dev/null
done
command -v gcc >/dev/null
command -v make >/dev/null
git config --global --get user.email | grep -q '@'
