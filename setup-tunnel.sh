#!/bin/bash
# ============================================================================
# Complete Pixel Debian Cellular Setup
# Installs all dependencies and configures cellular tunnel
# ============================================================================

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Pixel Debian Cellular - Complete Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script needs root"
    echo "   Run: sudo $0"
    exit 1
fi

# --- PHASE 1: INSTALL DEPENDENCIES ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Phase 1: Installing Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check internet connectivity
if ! timeout 5 ping -c 1 8.8.8.8 &> /dev/null; then
    echo "❌ No internet connection"
    echo "   Please connect to WiFi first for initial setup"
    exit 1
fi

echo "[*] Updating package lists..."
apt update || {
    echo "⚠️  apt update failed, continuing anyway..."
}

echo ""
echo "[*] Installing required packages..."

# List of required packages
PACKAGES=(
    "curl"
    "unzip"
    "iproute2"
    "iptables"
    "procps"
)

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo "   Installing $pkg..."
        apt install -y "$pkg" || {
            echo "⚠️  Failed to install $pkg, continuing..."
        }
    else
        echo "   ✓ $pkg already installed"
    fi
done

echo ""
echo "[+] System packages ready ✓"
echo ""

# --- PHASE 2: INSTALL TUN2SOCKS ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 Phase 2: Installing tun2socks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v tun2socks &> /dev/null; then
    CURRENT_VERSION=$(tun2socks -version 2>&1 | head -1 || echo "unknown")
    echo "[*] tun2socks already installed: $CURRENT_VERSION"
    echo ""
    read -p "Reinstall latest version? (y/n) " -n 1 -r
    echo
    if [[ ! \( REPLY =~ ^[Yy] \) ]]; then
        echo "[*] Skipping tun2socks installation"
        SKIP_TUN2SOCKS=true
    fi
fi

if [ "$SKIP_TUN2SOCKS" != "true" ]; then
    echo "[*] Detecting architecture..."
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    echo "   Architecture: $ARCH"
    
    echo ""
    echo "[*] Fetching latest release from GitHub..."
    VERSION=$(curl -s https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' 2>/dev/null || echo "")
    
    if [ -z "$VERSION" ]; then
        echo "⚠️  Could not fetch latest version, using v2.5.2"
        VERSION="2.5.2"
    fi
    
    echo "   Latest version: v$VERSION"
    
    DOWNLOAD_URL="https://github.com/xjasonlyu/tun2socks/releases/download/v\( {VERSION}/tun2socks-linux- \){ARCH}.zip"
    
    echo ""
    echo "[*] Downloading tun2socks v$VERSION..."
    curl -L --progress-bar "$DOWNLOAD_URL" -o /tmp/tun2socks.zip || {
        echo "❌ Download failed"
        exit 1
    }
    
    echo "[*] Extracting..."
    unzip -o -q /tmp/tun2socks.zip -d /tmp/
    
    echo "[*] Installing to /usr/local/bin..."
    mv /tmp/tun2socks-linux-${ARCH} /usr/local/bin/tun2socks
    chmod +x /usr/local/bin/tun2socks
    rm /tmp/tun2socks.zip
    
    INSTALLED_VERSION=$(tun2socks -version 2>&1 | head -1)
    echo ""
    echo "[+] tun2socks installed successfully ✓"
    echo "   $INSTALLED_VERSION"
fi

echo ""

# --- PHASE 3: DETECT NETWORK ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Phase 3: Network Configuration Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Configuration
TUN_NAME="tun0"
TUN_IP="198.18.0.1/30"
PROXY_PORT="1080"
INTERFACE="enp0s12"
LOG_FILE="/tmp/tun2socks.log"

echo "[*] Detecting network configuration..."

# Get Android host IP (proxy server)
ANDROID_IP=$(ip route | grep default | awk '{print $3}' | head -n 1)

# Get local gateway
SUBNET=$(ip addr show $INTERFACE 2>/dev/null | grep -oP 'inet \K[\d.]+/\d+' | head -1)
if [ -n "$SUBNET" ]; then
    GATEWAY=$(echo \( SUBNET | cut -d'/' -f1 | sed 's/\.[0-9]* \)/.1/')
else
    # Fallback: try to detect from route
    GATEWAY=$(ip route | grep "default" | awk '{print $3}' | head -n 1)
fi

if [ -z "$ANDROID_IP" ]; then
    echo "❌ Cannot detect Android host IP"
    echo ""
    echo "Current routes:"
    ip route show
    echo ""
    exit 1
fi

if [ -z "$GATEWAY" ]; then
    echo "⚠️  Cannot auto-detect gateway, using Android IP as gateway"
    GATEWAY="$ANDROID_IP"
fi

PROXY_IP="$ANDROID_IP"
PROXY_URL="socks5://\( {PROXY_IP}: \){PROXY_PORT}"

echo ""
echo "[+] Network Configuration Detected:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   • Android Host: $ANDROID_IP"
echo "   • Gateway: $GATEWAY"
echo "   • Interface: $INTERFACE"
echo "   • Proxy: $PROXY_IP:$PROXY_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- PHASE 4: VERIFY EVERY PROXY ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔌 Phase 4: Verify Every Proxy Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[*] Testing connection to proxy..."
if ! timeout 5 bash -c "echo > /dev/tcp/$PROXY_IP/$PROXY_PORT" 2>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ CANNOT REACH PROXY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Every Proxy is not reachable at $PROXY_IP:$PROXY_PORT"
    echo ""
    echo "Please configure Every Proxy on Android:"
    echo ""
    echo "  1. Install Every Proxy from Play Store"
    echo "     https://play.google.com/store/apps/details?id=com.gorillasoftware.everyproxy"
    echo ""
    echo "  2. Open Every Proxy app"
    echo ""
    echo "  3. Configure settings:"
    echo "     ┌─────────────────────────────┐"
    echo "     │ Server Type: SOCKS5         │"
    echo "     │ Port: 1080                  │"
    echo "     │ Bind Address: 0.0.0.0       │  ← IMPORTANT"
    echo "     │ Authentication: None/OFF    │"
    echo "     └─────────────────────────────┘"
    echo ""
    echo "  4. Tap START button"
    echo ""
    echo "  5. Verify notification: 'Proxy server running on port 1080'"
    echo ""
    echo "  6. Run this script again"
    echo ""
    exit 1
fi

echo "[+] Port $PROXY_PORT is reachable ✓"
echo ""

echo "[*] Testing SOCKS5 functionality..."
TEST_IP=$(timeout 10 curl -s -x socks5://$PROXY_IP:$PROXY_PORT ipinfo.io/ip 2>/dev/null || echo "")

if [ -z "$TEST_IP" ]; then
    echo "⚠️  WARNING: Port reachable but SOCKS5 not responding"
    echo ""
    echo "This might mean:"
    echo "  • Every Proxy is installed but not started"
    echo "  • Wrong server type (must be SOCKS5)"
    echo "  • Authentication is enabled (should be off)"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! \( REPLY =~ ^[Yy] \) ]]; then
        exit 1
    fi
else
    echo "[+] SOCKS5 working perfectly! ✓"
    echo "   Test IP: $TEST_IP"
fi

echo ""

# --- PHASE 5: CONFIGURE TUNNEL ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Phase 5: Configure Cellular Tunnel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 5.1: Cleanup
echo "[Step 5.1] Cleanup previous instances..."
pkill -f tun2socks 2>/dev/null || true
sleep 1
ip link delete $TUN_NAME 2>/dev/null || true
ip route del default dev $TUN_NAME 2>/dev/null || true
ip route del $PROXY_IP via $GATEWAY dev $INTERFACE 2>/dev/null || true
echo "   ✓ Cleanup complete"
echo ""

# Step 5.2: Proxy bypass route
echo "[Step 5.2] Configure proxy bypass route..."
echo "   Adding: $PROXY_IP via $GATEWAY dev $INTERFACE"
ip route add $PROXY_IP via $GATEWAY dev $INTERFACE || {
    echo "   ⚠️  Route may already exist, continuing..."
}
echo "   ✓ Bypass route configured"
echo ""

# Step 5.3: Start tun2socks
echo "[Step 5.3] Start tun2socks..."
echo "   Device: $TUN_NAME"
echo "   Proxy: $PROXY_URL"
echo "   Interface: $INTERFACE"
echo ""

setsid nohup tun2socks \
    -device "$TUN_NAME" \
    -proxy "$PROXY_URL" \
    -interface "$INTERFACE" \
    -loglevel info \
    > "$LOG_FILE" 2>&1 < /dev/null &

TUN2SOCKS_PID=$!
disown $TUN2SOCKS_PID || true
echo "   ✓ tun2socks started (PID: $TUN2SOCKS_PID)"
echo ""

# Wait for interface
echo "[Step 5.4] Waiting for tunnel interface..."
for i in {1..10}; do 
    if [ -d "/sys/class/net/$TUN_NAME" ]; then
        echo "   ✓ Interface $TUN_NAME created"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "   ❌ Interface failed to initialize"
        echo "   Check logs: tail $LOG_FILE"
        exit 1
    fi
    sleep 1
done
echo ""

# Step 5.5: Configure interface
echo "[Step 5.5] Configure tunnel interface..."
ip addr add $TUN_IP dev $TUN_NAME
ip link set dev $TUN_NAME up
echo "   ✓ Interface configured"
echo ""

# Step 5.6: Set routing
echo "[Step 5.6] Set default route through tunnel..."
ip route add default dev $TUN_NAME metric 1
echo "   ✓ Routing configured"
echo ""

# --- PHASE 6: VERIFY ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Phase 6: Verify Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 2

echo "[*] Testing connection through tunnel..."
PUBLIC_IP=$(timeout 15 curl -s --interface $TUN_NAME ipinfo.io/ip 2>/dev/null || echo "")

if [ -n "$PUBLIC_IP" ]; then
    CARRIER=$(timeout 10 curl -s --interface $TUN_NAME ipinfo.io/org 2>/dev/null | sed 's/^AS[0-9]* //' || echo "Unknown")
    LOCATION=$(timeout 10 curl -s --interface $TUN_NAME ipinfo.io/city 2>/dev/null || echo "Unknown")
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SETUP COMPLETE - TUNNEL ACTIVE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📱 Connection Details:"
    echo "   • Public IP: $PUBLIC_IP"
    echo "   • Carrier: $CARRIER"
    echo "   • Location: $LOCATION"
    echo "   • Via Proxy: $PROXY_IP:$PROXY_PORT"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Active Configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Routes:"
    ip route show | sed 's/^/   /'
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 Next Steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "   Test connection:"
    echo "     curl ipinfo.io/ip"
    echo ""
    echo "   View logs:"
    echo "     tail -f $LOG_FILE"
    echo ""
    echo "   Stop tunnel:"
    echo "     sudo pkill tun2socks"
    echo ""
    echo "   Process ID: $TUN2SOCKS_PID"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Your Debian terminal now uses cellular data!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ SETUP FAILED - NO CONNECTIVITY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Troubleshooting:"
    echo ""
    echo "1. Check tun2socks logs:"
    echo "   tail -20 $LOG_FILE"
    echo ""
    echo "2. Verify Every Proxy on Android:"
    echo "   • Is it running?"
    echo "   • SOCKS5 on 0.0.0.0:1080?"
    echo "   • Test: curl -x socks5://$PROXY_IP:$PROXY_PORT ipinfo.io/ip"
    echo ""
    echo "3. Check cellular data:"
    echo "   • Enabled in Android settings?"
    echo "   • Every Proxy has network permission?"
    echo ""
    echo "4. Verify routes:"
    echo "   ip route show"
    echo ""
    
    # Cleanup on failure
    echo "[*] Cleaning up..."
    pkill -f tun2socks 2>/dev/null || true
    ip link delete $TUN_NAME 2>/dev/null || true
    ip route del default dev $TUN_NAME 2>/dev/null || true
    ip route del $PROXY_IP via $GATEWAY dev $INTERFACE 2>/dev/null || true
    
    exit 1
fi
