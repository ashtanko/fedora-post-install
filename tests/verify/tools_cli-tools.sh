#!/bin/bash
set -euo pipefail
# Fedora packages expose the intended command names directly.
required=(bat fzf rg eza jq htop tmux tree gh)
for cmd in "${required[@]}"; do
    command -v "$cmd" >/dev/null || { echo "❌ missing: $cmd"; exit 1; }
done
