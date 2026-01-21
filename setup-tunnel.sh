#!/bin/bash
# ==========================================
# 🚀 2026 Interactive Tunnel Installer (Any SOCKS)
# Fully interactive, supports local, remote, and forwarded SOCKS servers
# ==========================================

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
DEFAULT_CHECK_INTERVAL=15

echo "------------------------------------------"
echo "[*] Starting Interactive Tunnel Installer..."
echo "------------------------------------------"

# --- INSTALL REQUIRED PACKAGES ---
install_dependencies() {
    echo "[*] Installing dependencies..."
    sudo apt update
    sudo apt install -y git curl unzip iproute2 procps
    echo "[+] Dependencies installed."
}

# --- INSTALL tun2socks ---
install_tun2socks() {
    if ! command -v tun2socks &>/dev/null; then
        echo "[*] Installing tun2socks..."
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        echo "[*] Detected architecture: $ARCH"

        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/xJasonlyu/tun2socks/releases/latest \
            | grep browser_download_url \
            | grep "linux-$ARCH.zip" \
            | cut -d '"' -f 4)

        if [ -z "$DOWNLOAD_URL" ]; then
            echo "[!] Failed to get download URL from GitHub."
            exit 1
        fi

        echo "[*] Downloading: $DOWNLOAD_URL"
        curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip

        echo "[*] Extracting tun2socks..."
        unzip -j /tmp/tun2socks.zip -d /tmp/

        echo "[*] Moving binary to /usr/local/bin..."
        sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
        sudo chmod +x /usr/local/bin/tun2socks
        echo "[+] tun2socks installed successfully."
    else
        echo "[+] tun2socks already installed."
    fi
}

# --- CLEANUP ---
cleanup_tun() {
    sudo pkill -f tun2socks &>/dev/null
    sudo ip link delete $TUN_NAME 2>/dev/null
    sudo ip route del default dev $TUN_NAME 2>/dev/null
}

# --- START TUN2SOCKS ---
start_tun2socks() {
    local proxy_ip=$1
    local proxy_port=$2
    local iface=$3

    cleanup_tun
    sudo sysctl -w net.ipv4.ip_forward=1

    echo "[*] Launching tun2socks -> $proxy_ip:$proxy_port on interface $iface"
    sudo tun2socks -device $TUN_NAME -proxy socks5://$proxy_ip:$proxy_port -interface $iface &

    # Wait for TUN
    for i in {1..15}; do
        if [ -d /sys/class/net/$TUN_NAME ]; then
            echo "[+] TUN interface $TUN_NAME is ready."
            break
        fi
        echo "[*] Waiting for $TUN_NAME..."
        sleep 1
    done

    sudo ip addr add $TUN_IP/30 dev $TUN_NAME 2>/dev/null
    sudo ip link set dev $TUN_NAME up
    sudo ip route add default dev $TUN_NAME metric 1 2>/dev/null
    echo "[+] TUN interface configured and default route set."
}

# --- VERIFY TUN TRAFFIC ---
verify_tunnel() {
    echo "[*] Verifying tunnel connectivity..."
    local public_ip
    public_ip=$(curl -s --max-time 10 https://ipinfo.io/ip)
    if [ -z "$public_ip" ]; then
        echo "[!] Tunnel not functional. Check your SOCKS server."
        return 1
    else
        echo "[+] Tunnel is live! Public IP: $public_ip"
        return 0
    fi
}

# --- MAIN INSTALL & LAUNCH ---
install_dependencies
install_tun2socks

# --- Ask user for SOCKS info ---
read -rp "[?] Enter SOCKS server IP or hostname: " SOCKS_HOST
read -rp "[?] Enter SOCKS server port [1080]: " SOCKS_PORT
SOCKS_PORT=${SOCKS_PORT:-1080}

# --- Determine interface to bind ---
read -rp "[?] Enter interface to bind for outgoing traffic [auto-detect]: " OUT_IFACE
if [ -z "$OUT_IFACE" ]; then
    # Auto-detect default interface
    OUT_IFACE=$(ip route | awk '/default/ {print $5; exit}')
fi
echo "[*] Using interface: $OUT_IFACE"

# --- Run Tunnel ---
while true; do
    start_tun2socks "$SOCKS_HOST" "$SOCKS_PORT" "$OUT_IFACE"
    sleep 5
    verify_tunnel
    echo "[*] Tunnel active. Monitoring network changes..."

    # --- MONITOR LOOP ---
    while true; do
        sleep $DEFAULT_CHECK_INTERVAL
    done
done

# --- CLEANUP ON EXIT ---
trap 'echo "[*] Cleaning up..."; cleanup_tun; exit' EXIT
