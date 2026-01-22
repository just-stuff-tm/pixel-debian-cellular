#!/bin/bash
set -e

echo "=============================================="
echo " Pixel Debian Experimental – tun2socks Setup "
echo "=============================================="
echo ""

# ---------- FUNCTIONS ----------
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "❌ Required command missing: $1"
        exit 1
    }
}

# ---------- REQUIREMENTS ----------
for cmd in ip awk sudo curl tar uname; do
    require_cmd "$cmd"
done

# ---------- PHASE 1: NETWORK AUTO-DETECTION ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Phase 1: Network auto-detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEF_IFACE=$(ip route show default | awk '{print $5}')
DEF_GW=$(ip route show default | awk '{print $3}')

# Most reliable way on Pixel
SRC_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')

if [ -z "$DEF_IFACE" ] || [ -z "$SRC_IP" ]; then
    echo "❌ Failed to auto-detect network parameters"
    exit 1
fi

echo "[+] Interface : $DEF_IFACE"
echo "[+] Gateway   : $DEF_GW"
echo "[+] Source IP : $SRC_IP"
echo ""

# ---------- PHASE 2: INSTALL TUN2SOCKS ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 Phase 2: Installing tun2socks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SKIP_TUN2SOCKS=false

if command -v tun2socks >/dev/null 2>&1; then
    CURRENT_VERSION=$(tun2socks -version 2>&1 | head -1 || echo "unknown")
    echo "[*] tun2socks already installed: $CURRENT_VERSION"
    echo ""
    read -p "Reinstall latest version? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[*] Skipping tun2socks installation"
        SKIP_TUN2SOCKS=true
    fi
fi

if [ "$SKIP_TUN2SOCKS" != "true" ]; then
    echo "[*] Detecting architecture..."
    ARCH=$(uname -m | sed \
        -e 's/x86_64/amd64/' \
        -e 's/aarch64/arm64/' \
        -e 's/armv7l/armv7/')

    echo "    Architecture: $ARCH"
    echo ""

    echo "[*] Fetching latest release from GitHub..."
    VERSION=$(curl -fsSL https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest \
        | awk -F'"' '/tag_name/{print $4}' | sed 's/^v//')

    if [ -z "$VERSION" ]; then
        echo "⚠️  Failed to fetch latest version, using fallback v2.5.2"
        VERSION="2.5.2"
    fi

    echo "    Version: v$VERSION"
    echo ""

    URL="https://github.com/xjasonlyu/tun2socks/releases/download/v${VERSION}/tun2socks-linux-${ARCH}.tar.gz"

    echo "[*] Downloading tun2socks..."
    curl -fL "$URL" -o /tmp/tun2socks.tar.gz

    echo "[*] Installing..."
    tar -xzf /tmp/tun2socks.tar.gz -C /tmp
    sudo install -m 0755 /tmp/tun2socks /usr/local/bin/tun2socks

    rm -f /tmp/tun2socks.tar.gz /tmp/tun2socks

    echo "✅ tun2socks v$VERSION installed successfully"
fi

# ---------- PHASE 3: SOCKS PROXY ----------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧦 Phase 3: SOCKS proxy configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "SOCKS5 proxy address [127.0.0.1:1080]: " SOCKS_PROXY
SOCKS_PROXY=${SOCKS_PROXY:-127.0.0.1:1080}

echo "[+] Using SOCKS proxy: $SOCKS_PROXY"
echo ""

# ---------- PHASE 4: TUN DEVICE ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔌 Phase 4: TUN device setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo ip tuntap add dev tun0 mode tun 2>/dev/null || true
sudo ip addr add 198.18.0.1/15 dev tun0 2>/dev/null || true
sudo ip link set tun0 up

echo "[+] tun0 is up"
echo ""

# ---------- PHASE 5: START TUN2SOCKS ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Phase 5: Starting tun2socks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "IMPORTANT:"
echo "- No system routing is modified (Pixel-safe)"
echo "- tun2socks will run in the foreground"
echo ""
echo "Test in another terminal:"
echo "  curl --interface tun0 https://ifconfig.me"
echo ""

read -p "Press ENTER to start tun2socks (Ctrl+C to cancel)..."

sudo tun2socks \
  -device tun0 \
  -proxy "socks5://$SOCKS_PROXY" \
  -interface "$DEF_IFACE"
  
