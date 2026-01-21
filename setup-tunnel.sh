#!/bin/bash
# ============================================================================
# Pixel Debian Terminal → Cellular Data (WORKING VERSION)
# Fixes: Auto-detects Android host IP, proper routing, correct tun2socks
# ============================================================================

set -e
trap cleanup EXIT INT TERM

cleanup() {
    if [ "$CLEANUP_NEEDED" = "true" ]; then
        echo "[*] Cleaning up on exit..."
        pkill -f tun2socks 2>/dev/null || true
        ip link delete tun0 2>/dev/null || true
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Pixel Debian → Cellular Tunnel (Fixed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
PROXY_PORT="1080"
LOG_FILE="/tmp/tun2socks.log"

# --- AUTO-DETECT ANDROID HOST ---
echo "[*] Detecting network configuration..."

# Get default gateway (Android host IP)
ANDROID_IP=$(ip route | grep default | awk '{print $3}' | head -n 1)
if [ -z "$ANDROID_IP" ]; then
    echo "❌ Cannot detect Android host IP"
    echo "   Run: ip route"
    exit 1
fi

# Get interface name
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
if [ -z "$INTERFACE" ]; then
    INTERFACE="enp0s12"  # Fallback
fi

PROXY_IP="$ANDROID_IP"
PROXY_URL="socks5://${PROXY_IP}:${PROXY_PORT}"

echo "[+] Network detected:"
echo "   • Android host: $ANDROID_IP"
echo "   • Interface: $INTERFACE"
echo "   • Proxy: $PROXY_IP:$PROXY_PORT"
echo ""

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script needs root"
    echo "   Run: sudo $0"
    exit 1
fi

# --- EVERY PROXY CHECK ---
echo "[*] Testing SOCKS5 proxy connection..."

if ! timeout 5 bash -c "echo > /dev/tcp/$PROXY_IP/$PROXY_PORT" 2>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Cannot reach proxy at $PROXY_IP:$PROXY_PORT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Fix Every Proxy configuration:"
    echo ""
    echo "  1. Open Every Proxy app on Android"
    echo "  2. Settings:"
    echo "     • Server Type: SOCKS5"
    echo "     • Port: 1080"
    echo "     • Bind Address: 0.0.0.0  ← IMPORTANT"
    echo "  3. Tap START"
    echo ""
    echo "Then test manually:"
    echo "  curl -x socks5://$PROXY_IP:1080 ipinfo.io/ip"
    echo ""
    exit 1
fi

echo "[+] Proxy is reachable ✓"
echo ""

# Test actual SOCKS functionality
echo "[*] Testing SOCKS5 functionality..."
TEST_IP=$(timeout 10 curl -s -x socks5://$PROXY_IP:$PROXY_PORT ipinfo.io/ip 2>/dev/null || echo "")

if [ -z "$TEST_IP" ]; then
    echo "⚠️  Proxy reachable but not responding to SOCKS5 requests"
    echo "   Check Every Proxy is actually started (not just installed)"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "[+] SOCKS5 working! Current IP: $TEST_IP ✓"
    echo ""
fi

# --- INSTALL TUN2SOCKS ---
if ! command -v tun2socks &> /dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Installing tun2socks (xjasonlyu version)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check internet
    if ! timeout 5 ping -c 1 8.8.8.8 &> /dev/null; then
        echo "❌ No internet. Connect to WiFi first."
        exit 1
    fi
    
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    echo "[*] Detected architecture: $ARCH"
    
    # Fetch latest version
    echo "[*] Fetching latest release info..."
    VERSION=$(curl -s https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        echo "⚠️  Cannot fetch latest version, using v2.5.2"
        VERSION="2.5.2"
    fi
    
    DOWNLOAD_URL="https://github.com/xjasonlyu/tun2socks/releases/download/v${VERSION}/tun2socks-linux-${ARCH}.zip"
    
    echo "[*] Downloading tun2socks v$VERSION..."
    curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip || {
        echo "❌ Download failed"
        exit 1
    }
    
    echo "[*] Extracting..."
    unzip -o /tmp/tun2socks.zip -d /tmp/
    
    echo "[*] Installing to /usr/local/bin..."
    mv /tmp/tun2socks-linux-${ARCH} /usr/local/bin/tun2socks
    chmod +x /usr/local/bin/tun2socks
    rm /tmp/tun2socks.zip
    
    echo "[+] tun2socks installed: $(tun2socks -version 2>&1 | head -1)"
    echo ""
fi

# --- CLEANUP OLD SESSIONS ---
echo "[*] Cleaning up old sessions..."
CLEANUP_NEEDED=true

pkill -f tun2socks 2>/dev/null || true
sleep 1

if ip link show $TUN_NAME &> /dev/null; then
    ip link delete $TUN_NAME 2>/dev/null || true
fi

ip route del default dev $TUN_NAME 2>/dev/null || true

echo "[+] Cleanup complete"
echo ""

# --- START TUN2SOCKS ---
echo "[*] Starting tun2socks..."
echo "   Proxy: $PROXY_URL"
echo "   Interface: $INTERFACE"
echo ""

tun2socks -device $TUN_NAME -proxy "$PROXY_URL" -interface "$INTERFACE" -loglevel info > "$LOG_FILE" 2>&1 &
TUN2SOCKS_PID=$!

echo "[+] tun2socks started (PID: $TUN2SOCKS_PID)"

# --- WAIT FOR INTERFACE ---
echo "[*] Waiting for tunnel interface..."

for i in {1..10}; do 
    if [ -d "/sys/class/net/$TUN_NAME" ]; then
        echo "[+] Interface $TUN_NAME created ✓"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ Interface failed to initialize"
        echo "   Check logs: tail $LOG_FILE"
        exit 1
    fi
    sleep 1
done

# --- CONFIGURE NETWORK ---
echo "[*] Configuring network..."

# Assign IP to tunnel
ip addr add "$TUN_IP/30" dev $TUN_NAME
ip link set dev $TUN_NAME up

# CRITICAL: Preserve route to proxy (prevent routing loop)
echo "[*] Adding route to proxy server..."
ip route add $PROXY_IP/32 via $ANDROID_IP dev $INTERFACE 2>/dev/null || true

# Set default route through tunnel (highest priority)
echo "[*] Setting default route through tunnel..."
ip route add default dev $TUN_NAME metric 1

echo "[+] Network configured ✓"
echo ""

# --- VERIFY CONNECTIVITY ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Testing cellular connection..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 2

PUBLIC_IP=$(timeout 15 curl -s --interface $TUN_NAME ipinfo.io/ip 2>/dev/null || echo "")

if [ -n "$PUBLIC_IP" ]; then
    # Success! Get more info
    CARRIER=$(timeout 10 curl -s --interface $TUN_NAME ipinfo.io/org 2>/dev/null | sed 's/^AS[0-9]* //' || echo "Unknown")
    LOCATION=$(timeout 10 curl -s --interface $TUN_NAME ipinfo.io/city 2>/dev/null || echo "Unknown")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SUCCESS! Cellular tunnel is ACTIVE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📱 Debian terminal now using cellular data!"
    echo ""
    echo "📊 Connection Details:"
    echo "   • Public IP: $PUBLIC_IP"
    echo "   • Carrier: $CARRIER"
    echo "   • Location: $LOCATION"
    echo "   • Via proxy: $PROXY_IP:$PROXY_PORT"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Routing Table:"
    ip route show | grep -E "default|$TUN_NAME|$PROXY_IP" | sed 's/^/   /'
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 Useful Commands:"
    echo "   • Test IP: curl ipinfo.io/ip"
    echo "   • Check status: ip route show"
    echo "   • View logs: tail -f $LOG_FILE"
    echo "   • Stop tunnel: sudo pkill tun2socks"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    CLEANUP_NEEDED=false
    
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Tunnel created but NO CONNECTIVITY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔍 Troubleshooting:"
    echo ""
    echo "1. Check tun2socks logs:"
    echo "   tail -20 $LOG_FILE"
    echo ""
    echo "2. Verify Every Proxy:"
    echo "   • Is it running?"
    echo "   • Bound to 0.0.0.0:1080?"
    echo "   • Test: curl -x socks5://$PROXY_IP:1080 ipinfo.io/ip"
    echo ""
    echo "3. Check cellular data:"
    echo "   • Is cellular data enabled in Android settings?"
    echo "   • Is Every Proxy allowed to use cellular?"
    echo ""
    echo "4. Test routing:"
    echo "   ip route show"
    echo ""
    exit 1
fi
