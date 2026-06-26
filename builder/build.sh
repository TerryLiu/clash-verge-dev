#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

MODE="${1:-fast}"

case "$MODE" in
  fast)
    echo "=== Fast build ==="
    pnpm build:fast 2>&1
    ;;
  release)
    echo "=== Release build ==="
    pnpm build 2>&1
    ;;
  *)
    echo "Usage: $0 [fast|release]"
    exit 1
    ;;
esac

echo ""
echo "✓ Build complete"
