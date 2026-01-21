#!/bin/bash
# ==========================================
# 🚀 2026 Auto-Detecting SOCKS Tunnel Installer
# Fully automatic: finds Pixel SOCKS server (Wi-Fi / USB / ADB)
# ==========================================

TUN_NAME="tun0"
TUN_IP="198.18.0.1"
DEFAULT_SOCKS_PORT=1080
CHECK_INTERVAL=10

echo "------------------------------------------"
echo "[*] Starting Auto-Detecting Tunnel Installer..."
echo "------------------------------------------"

# --- Dependencies ---
install_dependencies() {
    echo "[*] Installing dependencies..."
    sudo apt update
    sudo apt install -y git curl unzip iproute2 procps adb
    echo "[+] Dependencies installed."
}

# --- Install tun2socks ---
install_tun2socks() {
    if ! command -v tun2socks &>/dev/null; then
        echo "[*] Installing tun2socks..."
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/xJasonlyu/tun2socks/releases/latest \
            | grep browser_download_url \
            | grep "linux-$ARCH.zip" \
            | cut -d '"' -f 4)
        curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip
        unzip -j /tmp/tun2socks.zip -d /tmp/
        sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
        sudo chmod +x /usr/local/bin/tun2socks
        echo "[+] tun2socks installed successfully."
    else
        echo "[+] tun2socks already installed."
    fi
}

# --- Cleanup previous tunnel ---
cleanup_tun() {
    sudo pkill -f tun2socks &>/dev/null
    sudo ip link delete $TUN_NAME 2>/dev/null
    sudo ip route del default dev $TUN_NAME 2>/dev/null
}

# --- Detect reachable SOCKS ---
detect_socks() {
    echo "[*] Detecting reachable Pixel SOCKS server..."
    
    # 1. Check if ADB port forwarding is available
    if adb devices | grep -q "device$"; then
        adb forward tcp:$DEFAULT_SOCKS_PORT tcp:$DEFAULT_SOCKS_PORT 2>/dev/null
        echo "[+] Using ADB port forward on 127.0.0.1:$DEFAULT_SOCKS_PORT"
        echo "127.0.0.1 $DEFAULT_SOCKS_PORT"
        return
    fi

    # 2. Check local network (Wi-Fi hotspot)
    for ip in $(ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.\d+\.\d+'); do
        if curl --socks5 $ip:$DEFAULT_SOCKS_PORT --max-time 2 https://ipinfo.io/ip &>/dev/null; then
            echo "[+] Found reachable SOCKS at $ip:$DEFAULT_SOCKS_PORT"
            echo "$ip $DEFAULT_SOCKS_PORT"
            return
        fi
    done

    echo "[!] No reachable SOCKS server found. Please ensure Pixel is running SOCKS server."
    exit 1
}

# --- Start tun2socks ---
start_tun2socks() {
    local socks_ip=$1
    local socks_port=$2
    local iface=$3

    cleanup_tun
    sudo sysctl -w net.ipv4.ip_forward=1

    echo "[*] Launching tun2socks -> $socks_ip:$socks_port on interface $iface"
    sudo tun2socks -device $TUN_NAME -proxy socks5://$socks_ip:$socks_port -interface $iface &

    for i in {1..10}; do
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

# --- Verify tunnel ---
verify_tunnel() {
    echo "[*] Verifying tunnel connectivity..."
    local ip
    ip=$(curl --max-time 10 -s https://ipinfo.io/ip)
    if [ -z "$ip" ]; then
        echo "[!] Tunnel not functional. Check Pixel SOCKS server."
        return 1
    else
        echo "[+] Tunnel is live! Public IP: $ip"
        return 0
    fi
}

# --- Main ---
install_dependencies
install_tun2socks

# Detect SOCKS server automatically
read SOCKS_DETECTED_IP SOCKS_DETECTED_PORT < <(detect_socks)

# Auto-detect interface
OUT_IFACE=$(ip route | awk '/default/ {print $5; exit}')
echo "[*] Using interface: $OUT_IFACE"

# Start tunnel
while true; do
    start_tun2socks "$SOCKS_DETECTED_IP" "$SOCKS_DETECTED_PORT" "$OUT_IFACE"
    sleep 5
    verify_tunnel
    echo "[*] Tunnel active. Monitoring network..."
    while true; do sleep $CHECK_INTERVAL; done
done

trap 'echo "[*] Cleaning up..."; cleanup_tun; exit' EXIT
