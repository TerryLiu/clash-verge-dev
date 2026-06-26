#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

echo "=== Starting dev server ==="
pnpm dev 2>&1
