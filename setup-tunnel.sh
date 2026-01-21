#!/bin/bash
# ==========================================
# Auto-detect Android Tethering + SOCKS Proxy
# Reconnects if network changes
# ==========================================

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
DEFAULT_PROXY_PORT="1080"
LOG_FILE="/tmp/tun2socks.log"
CHECK_INTERVAL=15   # Seconds between checks

echo "------------------------------------------"
echo "[*] Starting Resilient Tunnel..."
echo "------------------------------------------"

# --- FUNCTION: Detect tethered interface ---
detect_tether_iface() {
    ip route show default | awk '/default/ {print $5; exit}'
}

# --- FUNCTION: Detect Android Gateway ---
detect_android_gateway() {
    ip route show default | awk '/default/ {print $3; exit}'
}

# --- FUNCTION: Install tun2socks if missing ---
install_tun2socks() {
    if ! command -v tun2socks &>/dev/null; then
        echo "[*] Installing tun2socks..."
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        VERSION=$(curl -s https://api.github.com/repos/xJasonlyu/tun2socks/releases/latest \
                  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        DOWNLOAD_URL="https://github.com/xJasonlyu/tun2socks/releases/download/${VERSION}/tun2socks-linux-${ARCH}.v${VERSION#v}.zip"
        sudo apt update && sudo apt install -y curl unzip
        curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip
        unzip -j /tmp/tun2socks.zip -d /tmp/
        sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
        sudo chmod +x /usr/local/bin/tun2socks
        echo "[+] tun2socks installed (v$VERSION)."
    fi
}

# --- FUNCTION: Start Tunnel ---
start_tunnel() {
    echo "[*] Launching tun2socks..."
    sudo pkill -f tun2socks &>/dev/null
    sudo ip link delete $TUN_NAME 2>/dev/null
    sudo ip route del default dev $TUN_NAME 2>/dev/null
    sudo sysctl -w net.ipv4.ip_forward=1 &>/dev/null

    sudo tun2socks -device $TUN_NAME -proxy $PROXY_URL -interface $PHYSICAL_IFACE > "$LOG_FILE" 2>&1 &

    # Wait for interface
    for i in {1..10}; do
        [ -d /sys/class/net/$TUN_NAME ] && break
        sleep 1
    done

    sudo ip addr add $TUN_IP/30 dev $TUN_NAME 2>/dev/null
    sudo ip link set dev $TUN_NAME up
    sudo ip route add default dev $TUN_NAME metric 1 2>/dev/null
}

# --- FUNCTION: Verify Tunnel ---
verify_tunnel() {
    PUBLIC_IP=$(curl -s --interface $TUN_NAME --max-time 10 ipinfo.io/ip)
    if [ ! -z "$PUBLIC_IP" ]; then
        echo "[+] Tunnel active! Public IP: $PUBLIC_IP"
        return 0
    else
        echo "[!] Tunnel not functional. Check Android proxy & log: $LOG_FILE"
        return 1
    fi
}

# --- INITIAL SETUP ---
install_tun2socks

while true; do
    PHYSICAL_IFACE=$(detect_tether_iface)
    PHYSICAL_GATEWAY=$(detect_android_gateway)

    if [ -z "$PHYSICAL_IFACE" ] || [ -z "$PHYSICAL_GATEWAY" ]; then
        echo "[!] Android tether not detected. Retrying in $CHECK_INTERVAL seconds..."
        sleep $CHECK_INTERVAL
        continue
    fi

    PROXY_IP="$PHYSICAL_GATEWAY"
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PROXY_PORT}
    PROXY_URL="socks5://${PROXY_IP}:${PROXY_PORT}"
    echo "[*] Detected Android host: $PROXY_IP via interface $PHYSICAL_IFACE"

    start_tunnel
    sleep 5

    if verify_tunnel; then
        echo "[*] Tunnel is live. Monitoring..."
    else
        echo "[!] Tunnel failed. Will retry in $CHECK_INTERVAL seconds..."
        sleep $CHECK_INTERVAL
        continue
    fi

    # --- MONITOR LOOP ---
    while true; do
        CURRENT_IFACE=$(detect_tether_iface)
        CURRENT_GATEWAY=$(detect_android_gateway)
        if [ "$CURRENT_IFACE" != "$PHYSICAL_IFACE" ] || [ "$CURRENT_GATEWAY" != "$PHYSICAL_GATEWAY" ]; then
            echo "[!] Network change detected. Rebuilding tunnel..."
            break
        fi
        sleep $CHECK_INTERVAL
    done
done
