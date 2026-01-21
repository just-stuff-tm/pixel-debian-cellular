#!/bin/bash
set -e

echo "------------------------------------------"
echo "🚀 Pixel Linux Tunnel Auto Installer"
echo "------------------------------------------"

# -------------------------
# Dependencies
# -------------------------
echo "[*] Installing dependencies..."
sudo apt update
sudo apt install -y git curl unzip iproute2 procps adb gcc
echo "[+] Dependencies installed."

# -------------------------
# Install tun2socks
# -------------------------
TUN2SOCKS_BIN="/usr/local/bin/tun2socks"
if ! command -v tun2socks &>/dev/null; then
    echo "[*] Installing tun2socks..."
    ARCH=$(uname -m)
    case $ARCH in
        aarch64) ARCH_TAG="arm64" ;;
        x86_64)  ARCH_TAG="amd64" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    curl -L -o /tmp/tun2socks.zip "https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-$ARCH_TAG.zip"
    unzip -o /tmp/tun2socks.zip -d /tmp/
    sudo mv /tmp/tun2socks-linux-$ARCH_TAG $TUN2SOCKS_BIN
    sudo chmod +x $TUN2SOCKS_BIN
    echo "[+] tun2socks installed."
else
    echo "[+] tun2socks already installed."
fi

# -------------------------
# Install dns2socks
# -------------------------
DNS2SOCKS_BIN="/usr/local/bin/dns2socks"
if ! command -v dns2socks &>/dev/null; then
    echo "[*] Installing dns2socks..."
    curl -L -o /tmp/dns2socks "https://github.com/tun2proxy/dns2socks/releases/download/v0.2.3/dns2socks_linux_arm64"
    if file /tmp/dns2socks | grep -q "ELF"; then
        sudo mv /tmp/dns2socks $DNS2SOCKS_BIN
        sudo chmod +x $DNS2SOCKS_BIN
        echo "[+] dns2socks installed successfully."
    else
        echo "[!] dns2socks download invalid. Exiting."
        cat /tmp/dns2socks
        exit 1
    fi
else
    echo "[+] dns2socks already installed."
fi

# -------------------------
# Detect Pixel SOCKS automatically
# -------------------------
echo "[*] Detecting reachable Pixel SOCKS server..."
# Detect devices via ADB (connected via USB or network)
PIXEL_IP=$(adb devices | awk '/device$/{print $1}' | head -n1)
if [ -z "$PIXEL_IP" ]; then
    echo "[!] No Pixel device detected via adb."
    exit 1
fi
SOCKS_PORT=1080
echo "[+] Found Pixel device at $PIXEL_IP, using SOCKS port $SOCKS_PORT"

# -------------------------
# Configure TUN interface
# -------------------------
echo "[*] Configuring TUN interface..."
sudo ip tuntap add dev tun0 mode tun
sudo ip link set tun0 up
sudo ip addr add 10.0.0.2/24 dev tun0
sudo ip route add default dev tun0
echo "[+] TUN interface tun0 is up and routing all traffic."

# -------------------------
# Start DNS over SOCKS
# -------------------------
echo "[*] Starting dns2socks for DNS over SOCKS..."
sudo $DNS2SOCKS_BIN 8.8.8.8 $PIXEL_IP $SOCKS_PORT 127.0.0.1:53 &

# -------------------------
# Launch tun2socks
# -------------------------
echo "[*] Launching tun2socks -> $PIXEL_IP:$SOCKS_PORT on interface enp0s12..."
sudo $TUN2SOCKS_BIN -device tun0 -proxy socks5://$PIXEL_IP:$SOCKS_PORT -interface enp0s12 -loglevel info
