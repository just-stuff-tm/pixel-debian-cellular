#!/bin/bash
set -e

echo "------------------------------------------"
echo "🚀 Pixel Linux Tunnel Installer"
echo "------------------------------------------"

# --- Dependencies ---
echo "[*] Installing dependencies..."
sudo apt update
sudo apt install -y git curl unzip iproute2 procps adb build-essential

echo "[+] Dependencies installed."

# --- Install tun2socks ---
T2S_VERSION="v2.6.0"
T2S_URL="https://github.com/xjasonlyu/tun2socks/releases/download/$T2S_VERSION/tun2socks-linux-arm64.zip"

if ! command -v tun2socks >/dev/null 2>&1; then
    echo "[*] Installing tun2socks..."
    TMPZIP="/tmp/tun2socks.zip"
    curl -L "$T2S_URL" -o "$TMPZIP"
    unzip -o "$TMPZIP" -d /tmp/
    sudo mv /tmp/tun2socks-linux-arm64 /usr/local/bin/tun2socks
    sudo chmod +x /usr/local/bin/tun2socks
    echo "[+] tun2socks installed."
else
    echo "[+] tun2socks already installed."
fi

# --- Install dns2socks ---
if ! command -v dns2socks >/dev/null 2>&1; then
    echo "[*] Installing dns2socks..."
    TMPDNS="/tmp/dns2socks"
    git clone https://github.com/txthinking/dns2socks.git "$TMPDNS"
    gcc "$TMPDNS/dns2socks.c" -o "$TMPDNS/dns2socks"
    sudo mv "$TMPDNS/dns2socks" /usr/local/bin/dns2socks
    sudo chmod +x /usr/local/bin/dns2socks
    echo "[+] dns2socks installed."
else
    echo "[+] dns2socks already installed."
fi

# --- Detect interface ---
DEFAULT_IF=$(ip route | grep default | awk '{print $5}')
read -p "[?] Enter interface to bind traffic [$DEFAULT_IF]: " IFACE
IFACE=${IFACE:-$DEFAULT_IF}
echo "[*] Using interface: $IFACE"

# --- Ask for SOCKS ---
read -p "[?] Enter Pixel SOCKS server IP: " SOCKS_IP
read -p "[?] Enter SOCKS server port [1080]: " SOCKS_PORT
SOCKS_PORT=${SOCKS_PORT:-1080}

# --- Enable IP forwarding ---
echo "[*] Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null

# --- Configure TUN ---
echo "[*] Configuring TUN interface..."
sudo ip tuntap add dev tun0 mode tun
sudo ip link set tun0 up
sudo ip addr add 10.0.0.1/24 dev tun0
sudo ip route add default dev tun0

# --- Start dns2socks ---
echo "[*] Starting dns2socks..."
dns2socks "127.0.0.1:53" "$SOCKS_IP:$SOCKS_PORT" 127.0.0.1:5353 >/dev/null 2>&1 &

# --- Start tun2socks ---
echo "[*] Launching tun2socks -> $SOCKS_IP:$SOCKS_PORT on $IFACE..."
sudo tun2socks -device tun0 -proxy "socks5://$SOCKS_IP:$SOCKS_PORT" -interface "$IFACE" &

echo "[+] TUN interface tun0 is up and routing all traffic."
echo "[+] Tunnel should now be active."
echo "[*] To test DNS over SOCKS: curl --interface tun0 https://ipinfo.io/ip"
