#!/bin/bash
# Patched setup-tunnel.sh - Stable Android Cellular Tunnel via tun2socks

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
LOG_FILE="/tmp/tun2socks.log"
PROXY_PORT="1080"

set -e
trap cleanup EXIT INT TERM

cleanup() {
    if [ "$CLEANUP_NEEDED" = "true" ]; then
        echo "[*] Cleaning up on exit..."
        pkill -f tun2socks 2>/dev/null || true
        ip link delete "$TUN_NAME" 2>/dev/null || true
    fi
}

# --- 0. Clean stale tun + previous tun2socks ---
ip link delete "$TUN_NAME" 2>/dev/null || true
pkill -f tun2socks 2>/dev/null || true
sleep 1

# --- 1. Detect Android host IP (ignore tun0) ---
ANDROID_IP=$(ip route show default | grep -v 'dev tun' | awk '/via/ {print $3}' | head -n1)

if ! [[ "$ANDROID_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Failed to detect Android IP (got: $ANDROID_IP)"
    echo "ℹ️  Hint: stop any existing tunnel or connect via USB/WiFi"
    exit 1
fi

PROXY_IP="$ANDROID_IP"
PROXY_URL="socks5://${PROXY_IP}:${PROXY_PORT}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Pixel Debian Terminal → Cellular Data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ℹ️  Detected Android host at: $ANDROID_IP"
echo ""

# --- 2. Check root permissions ---
if [ "$EUID" -ne 0 ]; then 
    echo "[!] This script needs root access"
    echo "[!] Run with: sudo ./setup-tunnel.sh"
    exit 1
fi

# --- 3. Verify SOCKS5 proxy ---
echo "[*] Verifying SOCKS5 proxy at $PROXY_IP:$PROXY_PORT..."
if ! timeout 5 bash -c "echo > /dev/tcp/$PROXY_IP/$PROXY_PORT" 2>/dev/null; then
    echo "❌ Cannot connect to SOCKS5 proxy"
    echo "Ensure Every Proxy is running and bound to 0.0.0.0"
    exit 1
fi
echo "[+] Proxy is reachable ✓"

# --- 4. Install tun2socks if missing ---
if ! command -v tun2socks &>/dev/null; then
    echo "[*] Installing tun2socks..."
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    VERSION=$(curl -s https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    [ -z "$VERSION" ] && VERSION="2.5.2"
    DOWNLOAD_URL="https://github.com/xjasonlyu/tun2socks/releases/download/v${VERSION}/tun2socks-linux-${ARCH}.zip"
    curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip
    unzip -o /tmp/tun2socks.zip -d /tmp/
    mv /tmp/tun2socks-linux-${ARCH} /usr/local/bin/tun2socks
    chmod +x /usr/local/bin/tun2socks
    rm /tmp/tun2socks.zip
    echo "[+] tun2socks installed ✓"
fi

# --- 5. Cleanup old tunnels ---
echo "[*] Cleaning up old tunnels..."
CLEANUP_NEEDED=true
pkill -f tun2socks 2>/dev/null || true
ip link delete "$TUN_NAME" 2>/dev/null || true
sleep 1

# --- 6. Start tun2socks ---
echo "[*] Launching cellular tunnel..."
tun2socks -device "$TUN_NAME" -proxy "$PROXY_URL" -loglevel info > "$LOG_FILE" 2>&1 &
TUN2SOCKS_PID=$!

echo "[*] Initializing interface..."
for i in {1..10}; do 
    if [ -d "/sys/class/net/$TUN_NAME" ]; then
        echo "[+] Interface created ✓"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "[!] Interface failed"
        exit 1
    fi
    sleep 1
done

# --- 7. Configure network ---
echo "[*] Configuring network..."
ip addr add "$TUN_IP/30" dev "$TUN_NAME"
ip link set dev "$TUN_NAME" up

# Preserve route to Android host (critical!)
ip route add $PROXY_IP via $ANDROID_IP dev enp0s12 2>/dev/null || true

# Add default route through tunnel
ip route add default dev "$TUN_NAME" metric 1 2>/dev/null || true
echo "[+] Routing configured ✓"

# --- 8. Verify connectivity ---
echo "[*] Testing cellular connection..."
sleep 2

PUBLIC_IP=$(timeout 15 curl -s --interface "$TUN_NAME" ipinfo.io/ip 2>/dev/null || echo "")

if [ -n "$PUBLIC_IP" ]; then
    CARRIER=$(timeout 10 curl -s --interface "$TUN_NAME" ipinfo.io/org 2>/dev/null | sed 's/^AS[0-9]* //' || echo "Unknown")
    LOCATION=$(timeout 10 curl -s --interface "$TUN_NAME" ipinfo.io/city 2>/dev/null || echo "Unknown")
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SUCCESS! Cellular data is now active"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📱 Debian terminal now has cellular internet!"
    echo ""
    echo "📊 Connection:"
    echo "   • IP: $PUBLIC_IP"
    echo "   • Carrier: $CARRIER"
    echo "   • Location: $LOCATION"
    echo "   • Via: $PROXY_IP:$PROXY_PORT"
    echo ""
    echo "Commands:"
    echo "   • Check: ./check-status.sh"
    echo "   • Logs: tail -f $LOG_FILE"
    echo "   • Stop: ./stop-tunnel.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    CLEANUP_NEEDED=false
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Tunnel created but no connection"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Check:"
    echo "  1. Every Proxy running with bind 0.0.0.0"
    echo "  2. Cellular data enabled"
    echo "  3. Logs: tail -f $LOG_FILE"
    echo ""
    exit 1
fi
