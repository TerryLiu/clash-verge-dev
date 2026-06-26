#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

HOST="${HOST:-$(rustc -vV | grep -oP '(?<=host: ).+')}"
SIDECAR_DIR="src-tauri/sidecar"
RESOURCES_DIR="src-tauri/resources"

RED='\033[31m'
GREEN='\033[32m'
NC='\033[0m'

log_ok()  { echo -e "${GREEN}✓${NC} $1"; }
log_err() { echo -e "${RED}✗${NC} $1"; }

mkdir -p "$SIDECAR_DIR" "$RESOURCES_DIR"

download() {
  local url="$1" out="$2" desc="$3"
  echo -n "  Downloading $desc... "
  if curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$out" 2>/dev/null; then
    log_ok "$(du -h "$out" | cut -f1)"
  else
    log_err "failed"
    return 1
  fi
}

echo "Host: $HOST"
echo ""

# ---- Mihomo Alpha ----
ALPHA_VER=$(curl -sf "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt")
echo "Alpha version: $ALPHA_VER"
download \
  "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-linux-amd64-v2-${ALPHA_VER}.gz" \
  "/tmp/mihomo-alpha.gz" \
  "mihomo-alpha"

gunzip -c /tmp/mihomo-alpha.gz > "$SIDECAR_DIR/verge-mihomo-alpha-$HOST"
chmod 755 "$SIDECAR_DIR/verge-mihomo-alpha-$HOST"
log_ok "verge-mihomo-alpha installed"

# ---- Mihomo Stable ----
STABLE_VER=$(curl -sfL "https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt")
echo "Stable version: $STABLE_VER"
download \
  "https://github.com/MetaCubeX/mihomo/releases/download/${STABLE_VER}/mihomo-linux-amd64-v2-${STABLE_VER}.gz" \
  "/tmp/mihomo-stable.gz" \
  "mihomo-stable"

gunzip -c /tmp/mihomo-stable.gz > "$SIDECAR_DIR/verge-mihomo-$HOST"
chmod 755 "$SIDECAR_DIR/verge-mihomo-$HOST"
log_ok "verge-mihomo installed"

# ---- Service ----
echo "Resolving service version..."
SERVICE_REDIRECT=$(curl -sfL -o /dev/null -w '%{url_effective}' \
  "https://github.com/clash-verge-rev/clash-verge-service-ipc/releases/latest")
SERVICE_VER=$(echo "$SERVICE_REDIRECT" | grep -oP '[^/]+$')
echo "Service version: $SERVICE_VER"

download \
  "https://github.com/clash-verge-rev/clash-verge-service-ipc/releases/download/${SERVICE_VER}/clash-verge-service-ipc-${SERVICE_VER}-${HOST}.tar.gz" \
  "/tmp/service-bundle.tar.gz" \
  "service bundle"

TEMP_DIR=$(mktemp -d)
tar xzf /tmp/service-bundle.tar.gz -C "$TEMP_DIR"
for BIN in clash-verge-service clash-verge-service-install clash-verge-service-uninstall; do
  find "$TEMP_DIR" -name "$BIN" -type f -exec cp {} "$SIDECAR_DIR/${BIN}-${HOST}" \; -print
  chmod 755 "$SIDECAR_DIR/${BIN}-${HOST}"
  log_ok "$BIN installed"
done
rm -rf "$TEMP_DIR" /tmp/service-bundle.tar.gz

# ---- Resources ----
echo "Downloading rule files..."
download \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb" \
  "$RESOURCES_DIR/Country.mmdb" \
  "Country.mmdb"

download \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" \
  "$RESOURCES_DIR/geosite.dat" \
  "geosite.dat"

download \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" \
  "$RESOURCES_DIR/geoip.dat" \
  "geoip.dat"

# ---- Cleanup ----
rm -f /tmp/mihomo-alpha.gz /tmp/mihomo-stable.gz

echo ""
echo "=== Download summary ==="
ls -lh "$SIDECAR_DIR"
echo ""
ls -lh "$RESOURCES_DIR"
