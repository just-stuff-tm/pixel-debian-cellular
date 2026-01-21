#!/bin/bash
# ==========================================
# 🚀 2026 Fully Resilient Tunnel (Daemon)
# Auto-installs dependencies, runs in background
# ==========================================

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
PHYSICAL_IFACE="enp0s12"       # Your tethered interface
DEFAULT_PROXY_PORT="1080"
LOG_FILE="/tmp/tun2socks.log"
CHECK_INTERVAL=15               # Seconds between network checks

# --- FUNCTIONS ---
install_dependencies() {
    echo "[*] Installing dependencies..."
    sudo apt update
    sudo apt install -y git curl unzip iproute2 procps
    echo "[+] Dependencies installed."
}

install_tun2socks() {
    if ! command -v tun2socks &>/dev/null; then
        echo "[*] Installing tun2socks..."
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        VERSION=$(curl -s https://api.github.com/repos/xJasonlyu/tun2socks/releases/latest \
                  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        DOWNLOAD_URL="https://github.com/xJasonlyu/tun2socks/releases/download/${VERSION}/tun2socks-linux-${ARCH}.v${VERSION#v}.zip"
        curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip
        unzip -j /tmp/tun2socks.zip -d /tmp/
        sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
        sudo chmod +x /usr/local/bin/tun2socks
        echo "[+] tun2socks installed (v$VERSION)."
    fi
}

cleanup_tun() {
    sudo pkill -f tun2socks &>/dev/null
    sudo ip link delete $TUN_NAME 2>/dev/null
    sudo ip route del default dev $TUN_NAME 2>/dev/null
}

start_tun2socks() {
    local proxy_ip=$1
    local proxy_port=$2

    cleanup_tun
    sudo sysctl -w net.ipv4.ip_forward=1 &>/dev/null

    echo "[*] Launching tun2socks -> $proxy_ip:$proxy_port"
    sudo tun2socks -device $TUN_NAME -proxy socks5://$proxy_ip:$proxy_port -interface $PHYSICAL_IFACE > "$LOG_FILE" 2>&1 &

    # Wait for TUN interface
    for i in {1..10}; do
        [ -d /sys/class/net/$TUN_NAME ] && break
        sleep 1
    done

    sudo ip addr add $TUN_IP/30 dev $TUN_NAME 2>/dev/null
    sudo ip link set dev $TUN_NAME up
    sudo ip route add default dev $TUN_NAME metric 1 2>/dev/null
    echo "[+] TUN interface $TUN_NAME is up."
}

verify_tunnel() {
    local public_ip
    public_ip=$(curl -s --max-time 10 https://ipinfo.io/ip)
    if [ -z "$public_ip" ]; then
        echo "[!] Tunnel not functional. Check proxy & log: $LOG_FILE"
        return 1
    else
        echo "[+] Tunnel is live. Public IP: $public_ip"
        return 0
    fi
}

# --- DAEMONIZE ---
if [ "$1" != "--daemon" ]; then
    echo "[*] Relaunching in background..."
    nohup sudo bash "$0" --daemon > /tmp/tunnel-daemon.log 2>&1 &
    echo "[+] Tunnel daemon started. Logs: /tmp/tunnel-daemon.log"
    exit 0
fi

# --- MAIN LOOP ---
install_dependencies
install_tun2socks

trap 'echo "[*] Cleaning up..."; cleanup_tun; exit' EXIT

while true; do
    PHYSICAL_GATEWAY=$(ip route show default | awk '/default/ {print $3; exit}')
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PROXY_PORT}

    if [ -z "$PHYSICAL_GATEWAY" ]; then
        echo "[!] Android host not detected. Retrying in $CHECK_INTERVAL seconds..."
        sleep $CHECK_INTERVAL
        continue
    fi

    echo "[*] Detected Android host: $PHYSICAL_GATEWAY via $PHYSICAL_IFACE"
    start_tun2socks "$PHYSICAL_GATEWAY" "$PROXY_PORT"

    sleep 5
    verify_tunnel && echo "[*] Tunnel active. Monitoring..." || echo "[!] Tunnel failed."

    # Monitor for network changes
    while true; do
        CURRENT_GATEWAY=$(ip route show default | awk '/default/ {print $3; exit}')
        if [ "$CURRENT_GATEWAY" != "$PHYSICAL_GATEWAY" ]; then
            echo "[!] Network change detected. Rebuilding tunnel..."
            break
        fi
        sleep $CHECK_INTERVAL
    done
done
