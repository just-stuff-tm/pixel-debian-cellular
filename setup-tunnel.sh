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

# ---------- CHECK REQUIRED COMMANDS ----------
for cmd in ip awk sudo curl tar unzip uname; do
    require_cmd "$cmd"
done

# ---------- PHASE 1: NETWORK AUTO-DETECTION ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Phase 1: Network auto-detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEF_IFACE=$(ip route show default | awk '{print $5}')
DEF_GW=$(ip route show default | awk '{print $3}')
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
    ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/' -e 's/armv7l/armv7/')
    echo "    Architecture: $ARCH"
    echo ""

    echo "[*] Fetching latest release metadata from GitHub..."
    RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest)
    ASSET_URL=$(echo "$RELEASE_JSON" | grep browser_download_url | grep "linux-$ARCH" | head -n1 | cut -d '"' -f4)

    if [ -z "$ASSET_URL" ]; then
        echo "❌ Could not find linux-$ARCH asset in release"
        exit 1
    fi

    echo "[+] Found asset: $ASSET_URL"
    TMP_FILE="/tmp/tun2socks.${ASSET_URL##*.}"
    curl -fL "$ASSET_URL" -o "$TMP_FILE"

    echo "[*] Installing..."
    if [[ "$TMP_FILE" == *.zip ]]; then
        unzip -o "$TMP_FILE" -d /tmp
        BINARY=$(ls /tmp | grep tun2socks-linux-$ARCH)
        sudo install -m 0755 "/tmp/$BINARY" /usr/local/bin/tun2socks
        rm -f "/tmp/$BINARY"
    else
        tar -xf "$TMP_FILE" -C /tmp
        sudo install -m 0755 /tmp/tun2socks /usr/local/bin/tun2socks
        rm -f /tmp/tun2socks
    fi

    rm -f "$TMP_FILE"
    echo "✅ tun2socks installed successfully"
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

# ---------- SYSTEM-WIDE EXPORT COMMANDS ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💻 Export commands for system-wide routing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "# Add these to ~/.bashrc or run in any terminal to route apps through SOCKS:"
echo "export ALL_PROXY=socks5h://$SOCKS_PROXY"
echo "export http_proxy=\$ALL_PROXY"
echo "export https_proxy=\$ALL_PROXY"
echo "export SOCKS_SERVER=$SOCKS_PROXY"
echo ""
echo "Example to apply immediately:"
echo "source ~/.bashrc"
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
  
