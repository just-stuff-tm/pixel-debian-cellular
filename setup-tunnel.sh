#!/bin/bash
# ==========================================
# 🚀 2026 Fully Automatic & Self-Healing Tunnel Installer
# Detects Pixel SOCKS, switches interfaces, rebuilds on network changes
# ==========================================

TUN_NAME="tun0"
TUN_IP="198.18.0.1"
DEFAULT_SOCKS_PORT=1080
CHECK_INTERVAL=10

echo "------------------------------------------"
echo "[*] Starting Fully Automatic Tunnel Installer..."
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
    
    # 1. ADB forwarding
    if adb devices | grep -q "device$"; then
        adb forward tcp:$DEFAULT_SOCKS_PORT tcp:$DEFAULT_SOCKS_PORT 2>/dev/null
        echo "[+] Using ADB port forward on 127.0.0.1:$DEFAULT_SOCKS_PORT"
        echo "127.0.0.1 $DEFAULT_SOCKS_PORT"
        return
    fi

    # 2. Scan local network
    for ip in $(ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.\d+\.\d+'); do
        if curl --socks5 $ip:$DEFAULT_SOCKS_PORT --max-time 2 https://ipinfo.io/ip &>/dev/null; then
            echo "[+] Found reachable SOCKS at $ip:$DEFAULT_SOCKS_PORT"
            echo "$ip $DEFAULT_SOCKS_PORT"
            return
        fi
    done

    echo "[!] No reachable SOCKS server found."
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
    local ip
    ip=$(curl --max-time 10 -s https://ipinfo.io/ip)
    if [ -z "$ip" ]; then
        echo "[!] Tunnel not functional."
        return 1
    else
        echo "[+] Tunnel is live! Public IP: $ip"
        return 0
    fi
}

# --- Monitor and auto-rebuild ---
monitor_tunnel() {
    local socks_ip=$1
    local socks_port=$2

    OUT_IFACE=$(ip route | awk '/default/ {print $5; exit}')
    while true; do
        start_tun2socks "$socks_ip" "$socks_port" "$OUT_IFACE"
        sleep 5
        if ! verify_tunnel; then
            echo "[*] Attempting to detect a new reachable SOCKS server..."
            read socks_ip socks_port < <(detect_socks)
            OUT_IFACE=$(ip route | awk '/default/ {print $5; exit}')
            echo "[*] Rebuilding tunnel with new SOCKS $socks_ip:$socks_port..."
        fi
        sleep $CHECK_INTERVAL
    done
}

# --- Main ---
install_dependencies
install_tun2socks

# Detect SOCKS server automatically
read SOCKS_IP SOCKS_PORT < <(detect_socks)

echo "[*] Starting self-healing tunnel..."
monitor_tunnel "$SOCKS_IP" "$SOCKS_PORT"

trap 'echo "[*] Cleaning up..."; cleanup_tun; exit' EXIT
