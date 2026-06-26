#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

# 前端产物目录不存在时，自动构建前端
if [ ! -d "dist" ]; then
  echo "=== Building frontend (dist/ not found) ==="
  pnpm run web:build 2>&1
  echo ""
fi

echo "=== cargo check ==="
cd src-tauri
cargo check 2>&1
echo ""
echo "✓ cargo check passed"
