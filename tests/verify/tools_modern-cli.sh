#!/bin/bash
set -euo pipefail
# Fedora packages plus the verified upstream lazygit release.
required=(lazygit delta btop direnv fd hyperfine dust tldr zoxide)
for cmd in "${required[@]}"; do
    command -v "$cmd" >/dev/null || { echo "❌ missing: $cmd"; exit 1; }
done
