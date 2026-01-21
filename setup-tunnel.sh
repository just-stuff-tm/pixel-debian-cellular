#!/bin/bash
set -e
echo "------------------------------------------"
echo "🚀 Pixel Linux Tunnel Installer"
echo "------------------------------------------"

# -------------------------------
# 1. Install dependencies
# -------------------------------
echo "[*] Installing dependencies..."
sudo apt update || true
sudo apt install -y git curl unzip iproute2 procps adb gcc || true
echo "[+] Dependencies installed."

# -------------------------------
# 2. Install tun2socks
# -------------------------------
TUN2SOCKS_BIN="/usr/local/bin/tun2socks"
if [ ! -f "$TUN2SOCKS_BIN" ]; then
    echo "[*] Installing tun2socks..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        URL="https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-arm64.zip"
    else
        echo "[!] Unsupported architecture: $ARCH"
        exit 1
    fi
    TMP_ZIP="/tmp/tun2socks.zip"
    curl -L -o $TMP_ZIP $URL
    unzip -o $TMP_ZIP -d /tmp
    sudo mv /tmp/tun2socks-linux-arm64 $TUN2SOCKS_BIN
    sudo chmod +x $TUN2SOCKS_BIN
    echo "[+] tun2socks installed."
else
    echo "[+] tun2socks already installed."
fi

# -------------------------------
# 3. Install dns2socks
# -------------------------------
DNS2SOCKS_BIN="/usr/local/bin/dns2socks"
if [ ! -f "$DNS2SOCKS_BIN" ]; then
    echo "[*] Installing dns2socks..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        URL="https://github.com/tun2proxy/dns2socks/releases/download/v0.2.3/dns2socks_linux_arm64"
    else
        echo "[!] Unsupported architecture: $ARCH"
        exit 1
    fi
    sudo curl -L -o $DNS2SOCKS_BIN $URL
    sudo chmod +x $DNS2SOCKS_BIN
    echo "[+] dns2socks installed."
else
    echo "[+] dns2socks already installed."
fi

# -------------------------------
# 4. Detect interface and SOCKS server
# -------------------------------
IFACE=$(ip route | grep default | awk '{print $5}')
echo "[*] Using interface: $IFACE"
read -p "[?] Enter Pixel SOCKS IP: " SOCKS_IP
read -p "[?] Enter SOCKS port [1080]: " SOCKS_PORT
SOCKS_PORT=${SOCKS_PORT:-1080}

# -------------------------------
# 5. Configure TUN
# -------------------------------
echo "[*] Configuring TUN interface..."
sudo ip tuntap add dev tun0 mode tun
sudo ip addr add 10.0.0.2/24 dev tun0
sudo ip link set dev tun0 up
sudo ip route add default dev tun0
echo "[+] TUN interface tun0 is up and routing all traffic."

# -------------------------------
# 6. Start dns2socks
# -------------------------------
echo "[*] Starting dns2socks for DNS over SOCKS..."
sudo $DNS2SOCKS_BIN -l 127.0.0.1:53 -d 8.8.8.8:53 -s socks5://$SOCKS_IP:$SOCKS_PORT &
DNS2SOCKS_PID=$!
# Point system DNS to local dns2socks
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# -------------------------------
# 7. Start tun2socks
# -------------------------------
echo "[*] Launching tun2socks -> $SOCKS_IP:$SOCKS_PORT on interface $IFACE..."
sudo $TUN2SOCKS_BIN -device tun0 -proxy socks5://$SOCKS_IP:$SOCKS_PORT -interface $IFACE

# -------------------------------
# 8. Cleanup on exit
# -------------------------------
cleanup() {
    echo "[*] Cleaning up..."
    sudo kill $DNS2SOCKS_PID || true
    sudo ip link set tun0 down || true
    sudo ip tuntap del dev tun0 mode tun || true
}
trap cleanup EXIT
