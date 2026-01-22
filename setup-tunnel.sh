#!/bin/bash
set -e

echo "=============================================="
echo " Pixel Debian Experimental – tun2socks Setup "
echo "=============================================="

# ---------- FUNCTIONS ----------
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "❌ Required command missing: $1"
        exit 1
    }
}

# ---------- REQUIREMENTS ----------
for cmd in ip awk sudo go; do
    require_cmd "$cmd"
done

# ---------- INSTALL DEPENDENCIES ----------
if ! command -v tun2socks >/dev/null 2>&1; then
    echo "[*] Installing dependencies..."
    sudo apt update
    sudo apt install -y golang-go git

    echo "[*] Installing tun2socks..."
    go install github.com/xjasonlyu/tun2socks/v2@latest
fi

TUN2SOCKS_BIN="$HOME/go/bin/tun2socks"

if [ ! -x "$TUN2SOCKS_BIN" ]; then
    echo "❌ tun2socks binary not found at $TUN2SOCKS_BIN"
    exit 1
fi

# ---------- NETWORK AUTO-DETECTION ----------
DEF_IFACE=$(ip route show default | awk '{print $5}')
DEF_GW=$(ip route show default | awk '{print $3}')

# Most reliable "actual IP" detection for Pixel
SRC_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')

echo "[+] Interface : $DEF_IFACE"
echo "[+] Gateway   : $DEF_GW"
echo "[+] Source IP : $SRC_IP"

if [ -z "$DEF_IFACE" ] || [ -z "$SRC_IP" ]; then
    echo "❌ Failed to auto-detect network parameters"
    exit 1
fi

# ---------- SOCKS PROXY ----------
read -p "SOCKS5 proxy address [127.0.0.1:1080]: " SOCKS_PROXY
SOCKS_PROXY=${SOCKS_PROXY:-127.0.0.1:1080}

# ---------- TUN DEVICE ----------
echo "[*] Preparing tun0..."

sudo ip tuntap add dev tun0 mode tun 2>/dev/null || true
sudo ip addr add 198.18.0.1/15 dev tun0 2>/dev/null || true
sudo ip link set tun0 up

# ---------- INFO ----------
echo ""
echo "IMPORTANT:"
echo "- No system routing is modified (Pixel-safe)"
echo "- Use apps that can bind to tun0 or SOCKS"
echo "- tun2socks will run in the foreground"
echo ""
echo "Suggested test command in another terminal:"
echo "  curl --interface tun0 https://ifconfig.me"
echo ""

read -p "Press ENTER to start tun2socks (Ctrl+C to cancel)..."

# ---------- START TUN2SOCKS ----------
echo "[*] Starting tun2socks..."

sudo "$TUN2SOCKS_BIN" \
  -device tun0 \
  -proxy "socks5://$SOCKS_PROXY" \
  -interface "$DEF_IFACE"
  
