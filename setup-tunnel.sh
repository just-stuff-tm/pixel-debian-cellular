#!/bin/bash
# Fixed version - Auto-detects Android host IP

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
LOG_FILE="/tmp/tun2socks.log"

# Auto-detect Android host IP (gateway)
ANDROID_IP=$(ip route | grep default | awk '{print $3}' | head -n 1)

if [ -z "$ANDROID_IP" ]; then
    echo "❌ Cannot detect Android host IP"
    exit 1
fi

PROXY_IP="$ANDROID_IP"  # Use gateway IP instead of 127.0.0.1
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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Pixel Debian Terminal → Cellular Data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ℹ️  Detected Android host at: $ANDROID_IP"
echo ""

# 1. CHECK ROOT/PERMISSIONS
if [ "$EUID" -ne 0 ]; then 
    echo "[!] This script needs root access"
    echo "[!] Run with: sudo ./setup-tunnel-fixed.sh"
    exit 1
fi

# 2. CHECK WIFI FOR INITIAL SETUP
if ! command -v tun2socks &> /dev/null; then
    echo "[*] First-time setup - checking WiFi for download..."
    
    if ! timeout 5 ping -c 1 8.8.8.8 &> /dev/null; then
        echo "❌ No internet - connect to WiFi first"
        exit 1
    fi
    echo "[+] WiFi connected ✓"
fi

# 3. PROXY CHECK
echo "[*] Verifying SOCKS5 proxy at $PROXY_IP:$PROXY_PORT..."
if ! timeout 5 bash -c "echo > /dev/tcp/$PROXY_IP/$PROXY_PORT" 2>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Cannot connect to SOCKS5 proxy"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Fix Every Proxy configuration:"
    echo "  1. Open Every Proxy app"
    echo "  2. Change 'Bind Address' to: 0.0.0.0"
    echo "  3. Tap START"
    echo ""
    echo "Then test: curl -x socks5://$PROXY_IP:1080 ipinfo.io/ip"
    echo ""
    exit 1
fi
echo "[+] Proxy is reachable ✓"

PROXY_URL="socks5://${PROXY_IP}:${PROXY_PORT}"

# 4. INSTALL TUN2SOCKS
if ! command -v tun2socks &> /dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Installing tun2socks (one-time)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    VERSION=$(curl -s https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        VERSION="2.5.2"
    fi
    
    DOWNLOAD_URL="https://github.com/xjasonlyu/tun2socks/releases/download/v${VERSION}/tun2socks-linux-${ARCH}.zip"
    echo "[*] Downloading v$VERSION..."
    
    curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip
    unzip -o /tmp/tun2socks.zip -d /tmp/
    mv /tmp/tun2socks-linux-${ARCH} /usr/local/bin/tun2socks
    chmod +x /usr/local/bin/tun2socks
    rm /tmp/tun2socks.zip
    echo "[+] Installation complete ✓"
fi

# 5. CLEANUP OLD
echo "[*] Cleaning up old tunnels..."
CLEANUP_NEEDED=true
pkill -f tun2socks 2>/dev/null || true
ip link delete "$TUN_NAME" 2>/dev/null || true
sleep 1

# 6. START TUN2SOCKS
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

# 7. CONFIGURE
echo "[*] Configuring network..."
ip addr add "$TUN_IP/30" dev "$TUN_NAME"
ip link set dev "$TUN_NAME" up

# Preserve route to Android host (critical!)
ip route add $PROXY_IP via $ANDROID_IP dev enp0s12

# Add default route through tunnel
ip route add default dev "$TUN_NAME" metric 1

echo "[+] Routing configured ✓"

# 8. VERIFY
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
