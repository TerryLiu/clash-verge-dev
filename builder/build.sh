#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

MODE="${1:-deb}"

case "$MODE" in
  deb)
    echo "=== Building .deb package (fast-release) ==="
    pnpm build:fast 2>&1
    echo ""
    echo "✓ Build complete"
    echo "Packages:"
    ls -lh target/fast-release/bundle/deb/*.deb 2>/dev/null
    echo ""
    echo "Binary: target/fast-release/clash-verge"
    ;;

  bin)
    echo "=== Building binary only ==="
    pnpm run web:build 2>&1
    echo ""
    cargo build --profile fast-release 2>&1
    echo ""
    echo "✓ Build complete"
    echo "Binary: $(pwd)/target/fast-release/clash-verge"
    ls -lh target/fast-release/clash-verge
    ;;

  release)
    echo "=== Building release .deb ==="
    pnpm build 2>&1
    echo ""
    echo "✓ Build complete"
    echo "Packages:"
    ls -lh target/release/bundle/deb/*.deb 2>/dev/null
    ;;

  *)
    echo "Usage: $0 [deb|bin|release]"
    echo "  deb     - fast-release .deb package (default)"
    echo "  bin     - binary only, no package"
    echo "  release - full optimized release .deb"
    exit 1
    ;;
esac
