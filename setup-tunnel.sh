#!/bin/bash
# Fixed installer - IPv4 only, idempotent, stable

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
LOG_FILE="/tmp/tun2socks.log"

set -euo pipefail

cleanup() {
    if [ "${CLEANUP_NEEDED:-false}" = "true" ]; then
        echo "[*] Cleaning up on exit..."
        pkill -f tun2socks 2>/dev/null || true
        ip link delete "$TUN_NAME" 2>/dev/null || true
    fi
}

trap cleanup INT TERM

# --- DETECT ANDROID HOST (gateway) ---
ANDROID_IP=$(ip route show default 0.0.0.0/0 | awk '{print $3}' | head -n 1)

if [ -z "$ANDROID_IP" ]; then
    echo "❌ Cannot detect Android host IP"
    exit 1
fi

PROXY_IP="$ANDROID_IP"
PROXY_PORT="1080"
PROXY_URL="socks5://${PROXY_IP}:${PROXY_PORT}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Pixel Debian Terminal → Cellular Data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ℹ️  Detected Android host at: $ANDROID_IP"
echo ""

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then
    echo "[!] This script needs root access"
    echo "[!] Run with: sudo ./setup-tunnel.sh"
    exit 1
fi

# --- PROXY CHECK ---
echo "[*] Verifying SOCKS5 proxy at $PROXY_IP:$PROXY_PORT..."
if ! timeout 5 bash -c "echo > /dev/tcp/$PROXY_IP/$PROXY_PORT" 2>/dev/null; then
    echo "❌ Cannot connect to SOCKS5 proxy"
    echo "Ensure Every Proxy is running and bound to 0.0.0.0"
    exit 1
fi
echo "[+] Proxy is reachable ✓"

# --- INSTALL TUN2SOCKS (ONE-TIME) ---
if ! command -v tun2socks >/dev/null 2>&1; then
    echo "📦 Installing tun2socks..."
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    VERSION=$(curl -fsSL https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest \
        | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)
    VERSION=${VERSION:-2.5.2}

    curl -L "https://github.com/xjasonlyu/tun2socks/releases/download/v${VERSION}/tun2socks-linux-${ARCH}.zip" \
        -o /tmp/tun2socks.zip
    unzip -o /tmp/tun2socks.zip -d /tmp/
    install -m 755 /tmp/tun2socks-linux-${ARCH} /usr/local/bin/tun2socks
    rm -f /tmp/tun2socks.zip
    echo "[+] tun2socks installed ✓"
fi

# --- CLEAN OLD STATE ---
echo "[*] Cleaning up old tunnels..."
CLEANUP_NEEDED=true
pkill -f tun2socks 2>/dev/null || true
ip link delete "$TUN_NAME" 2>/dev/null || true
sleep 1

# --- START TUN2SOCKS ---
echo "[*] Launching cellular tunnel..."
tun2socks \
    -device "$TUN_NAME" \
    -proxy "$PROXY_URL" \
    -loglevel info \
    > "$LOG_FILE" 2>&1 &

TUN2SOCKS_PID=$!

# --- WAIT FOR INTERFACE ---
echo "[*] Initializing interface..."
for i in {1..10}; do
    if ip link show "$TUN_NAME" >/dev/null 2>&1; then
        echo "[+] Interface created ✓"
        break
    fi
    sleep 1
done

if ! ip link show "$TUN_NAME" >/dev/null 2>&1; then
    echo "❌ TUN interface failed to appear"
    exit 1
fi

# --- CONFIGURE INTERFACE ---
echo "[*] Configuring network..."
ip addr replace "$TUN_IP/30" dev "$TUN_NAME"
ip link set "$TUN_NAME" up

# --- PRESERVE ROUTE TO ANDROID HOST ---
ANDROID_IFACE=$(ip route get "$ANDROID_IP" | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')

ip route replace "$ANDROID_IP" dev "$ANDROID_IFACE" scope link

# --- DEFAULT ROUTE THROUGH TUN ---
ip route replace default dev "$TUN_NAME" metric 1

echo "[+] Routing configured ✓"

# --- VERIFY CONNECTIVITY ---
echo "[*] Testing cellular connection..."
sleep 2

PUBLIC_IP=$(timeout 15 curl -s --interface "$TUN_NAME" ipinfo.io/ip || true)

if [ -n "$PUBLIC_IP" ]; then
    CARRIER=$(timeout 10 curl -s --interface "$TUN_NAME" ipinfo.io/org | sed 's/^AS[0-9]* //' || echo "Unknown")
    LOCATION=$(timeout 10 curl -s --interface "$TUN_NAME" ipinfo.io/city || echo "Unknown")

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
    echo "❌ Tunnel created but no connectivity"
    echo "Check logs: tail -f $LOG_FILE"
    exit 1
fi
