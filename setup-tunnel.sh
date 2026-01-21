#!/bin/bash
# ==============================
# Pixel Debian Cellular Tunnel
# Fully Interactive Installer
# ==============================

# --- CONFIGURATION ---
TUN_NAME="tun0"
TUN_IP="198.18.0.1"
DEFAULT_SOCKS_PORT=1080

echo "------------------------------------------"
echo "🚀 Pixel Linux Tunnel Installer"
echo "------------------------------------------"

# --- HELPER FUNCTIONS ---

install_dependencies() {
    echo "[*] Installing dependencies..."
    sudo apt update
    sudo apt install -y git curl unzip iproute2 procps adb
    echo "[+] Dependencies installed."
}

install_tun2socks() {
    if ! command -v tun2socks &>/dev/null; then
        echo "[*] Installing tun2socks..."
        ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
        VERSION="v2.6.0"
        DOWNLOAD_URL="https://github.com/xJasonlyu/tun2socks/releases/download/${VERSION}/tun2socks-linux-${ARCH}.zip"

        echo "[*] Downloading $DOWNLOAD_URL ..."
        curl -L "$DOWNLOAD_URL" -o /tmp/tun2socks.zip

        echo "[*] Extracting tun2socks..."
        unzip -o /tmp/tun2socks.zip -d /tmp/
        sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
        sudo chmod +x /usr/local/bin/tun2socks
        echo "[+] tun2socks installed successfully."
    else
        echo "[+] tun2socks already installed."
    fi
}

detect_interface() {
    # Auto-detect default interface
    PHYS_IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    if [ -z "$PHYS_IFACE" ]; then
        read -rp "[?] Could not auto-detect interface. Enter interface name: " PHYS_IFACE
    fi
    echo "[*] Using interface: $PHYS_IFACE"
}

get_socks_server() {
    echo "[*] Detecting reachable Pixel SOCKS server..."

    # Try ADB forward if device connected
    if adb devices | grep -q "device$"; then
        adb forward tcp:$DEFAULT_SOCKS_PORT tcp:$DEFAULT_SOCKS_PORT
        echo "[+] Using ADB forward at 127.0.0.1:$DEFAULT_SOCKS_PORT"
        SOCKS_IP="127.0.0.1"
        SOCKS_PORT=$DEFAULT_SOCKS_PORT
        return
    fi

    # Manual input fallback
    read -rp "[?] Enter Pixel SOCKS IP: " SOCKS_IP
    read -rp "[?] Enter SOCKS port [${DEFAULT_SOCKS_PORT}]: " SOCKS_PORT
    SOCKS_PORT=${SOCKS_PORT:-$DEFAULT_SOCKS_PORT}

    if [[ -z "$SOCKS_IP" || -z "$SOCKS_PORT" ]]; then
        echo "[!] Invalid SOCKS server. Exiting."
        exit 1
    fi
}

start_tunnel() {
    echo "[*] Cleaning previous sessions..."
    sudo pkill -f tun2socks 2>/dev/null
    sudo ip link delete $TUN_NAME 2>/dev/null
    sleep 1

    echo "[*] Starting tunnel..."
    sudo tun2socks -device $TUN_NAME -proxy socks5://$SOCKS_IP:$SOCKS_PORT -interface $PHYS_IFACE
}

configure_tun() {
    echo "[*] Configuring TUN interface..."
    sudo ip addr add $TUN_IP/30 dev $TUN_NAME 2>/dev/null
    sudo ip link set dev $TUN_NAME up
    sudo ip route add default dev $TUN_NAME metric 1
    echo "[+] TUN interface $TUN_NAME is up and routing all traffic."
}

verify_tunnel() {
    echo "[*] Verifying tunnel connectivity..."
    PUBLIC_IP=$(curl -s --interface $TUN_NAME --max-time 10 ipinfo.io/ip)
    if [ -n "$PUBLIC_IP" ]; then
        echo "------------------------------------------"
        echo "✅ Tunnel is active!"
        echo "🌍 Public IP: $PUBLIC_IP"
        echo "------------------------------------------"
    else
        echo "------------------------------------------"
        echo "❌ Tunnel up but no internet."
        echo "🔍 Check Pixel SOCKS server or interface."
        echo "------------------------------------------"
    fi
}

# --- MAIN INSTALLER FLOW ---

install_dependencies
install_tun2socks
detect_interface
get_socks_server
configure_tun
start_tunnel
verify_tunnel
