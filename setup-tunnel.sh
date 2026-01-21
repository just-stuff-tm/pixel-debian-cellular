#!/bin/bash
# ==========================================
# 🚀 2026 Fully Interactive Tunnel Installer
# Shows all output in terminal, installs dependencies, routes traffic
# ==========================================

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
PHYSICAL_IFACE="enp0s12"       # Your tethered interface
DEFAULT_PROXY_PORT="1080"
CHECK_INTERVAL=15               # Seconds between network checks

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

# --- INSTALL tun2socks IF MISSING ---
install_tun2socks() {
    if ! command -v tun2socks &>/dev/null; then
        echo "[*] Installing tun2socks..."
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        VERSION=$(curl -s https://api.github.com/repos/xJasonlyu/tun2socks/releases/latest \
                  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        echo "[*] Latest release detected: $VERSION"
        DOWNLOAD_URL="https://github.com/xJasonlyu/tun2socks/releases/download/${VERSION}/tun2socks-linux-${ARCH}.v${VERSION#v}.zip"
        echo "[*] Downloading: $DOWNLOAD_URL"
        curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip
        echo "[*] Extracting tun2socks..."
        unzip -j /tmp/tun2socks.zip -d /tmp/
        echo "[*] Moving binary to /usr/local/bin..."
        sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
        sudo chmod +x /usr/local/bin/tun2socks
        echo "[+] tun2socks installed."
    else
        echo "[+] tun2socks already installed."
    fi
}

# --- CLEANUP TUN ---
cleanup_tun() {
    sudo pkill -f tun2socks &>/dev/null
    sudo ip link delete $TUN_NAME 2>/dev/null
    sudo ip route del default dev $TUN_NAME 2>/dev/null
}

# --- START TUN2SOCKS ---
start_tun2socks() {
    local proxy_ip=$1
    local proxy_port=$2

    cleanup_tun
    sudo sysctl -w net.ipv4.ip_forward=1

    echo "[*] Launching tun2socks -> $proxy_ip:$proxy_port"
    sudo tun2socks -device $TUN_NAME -proxy socks5://$proxy_ip:$proxy_port -interface $PHYSICAL_IFACE &
    
    # Wait for TUN interface
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
        echo "[!] Tunnel not functional. Check Android proxy."
        return 1
    else
        echo "[+] Tunnel is live! Public IP: $public_ip"
        return 0
    fi
}

# --- MAIN INSTALL & LAUNCH ---
install_dependencies
install_tun2socks

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
    verify_tunnel

    echo "[*] Tunnel active. Monitoring for network changes..."
    # --- MONITOR LOOP ---
    while true; do
        CURRENT_GATEWAY=$(ip route show default | awk '/default/ {print $3; exit}')
        if [ "$CURRENT_GATEWAY" != "$PHYSICAL_GATEWAY" ]; then
            echo "[!] Network change detected. Rebuilding tunnel..."
            break
        fi
        sleep $CHECK_INTERVAL
    done
done

# --- CLEANUP ON EXIT ---
trap 'echo "[*] Cleaning up..."; cleanup_tun; exit' EXIT
