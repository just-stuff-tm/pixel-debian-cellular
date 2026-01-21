#!/bin/bash
set -e

echo "------------------------------------------"
echo "🚀 Pixel VM SOCKS Tunnel Installer"
echo "------------------------------------------"

# --- Dependencies ---
echo "[*] Installing dependencies..."
sudo apt update
sudo apt install -y git curl unzip iproute2 procps gcc

# --- Detect network interface and host IP ---
INTERFACE=$(ip route | grep default | awk '{print $5}')
HOST_IP=$(ip route | grep default | awk '{print $3}')

echo "[*] Using interface: $INTERFACE"
echo "[*] Detected Android host IP: $HOST_IP"

# --- Default SOCKS port ---
SOCKS_PORT=1080

# --- Check/install tun2socks ---
if ! command -v tun2socks >/dev/null 2>&1; then
    echo "[*] Installing tun2socks..."
    TMP_ZIP="/tmp/tun2socks.zip"
    curl -L -o $TMP_ZIP https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-arm64.zip
    unzip -o $TMP_ZIP -d /tmp
    sudo mv /tmp/tun2socks-linux-arm64 /usr/local/bin/tun2socks
    sudo chmod +x /usr/local/bin/tun2socks
fi
echo "[+] tun2socks installed."

# --- Check/install dns2socks ---
if ! command -v dns2socks >/dev/null 2>&1; then
    echo "[*] Installing dns2socks..."
    TMP_DNS="/tmp/dns2socks"
    curl -L -o $TMP_DNS https://github.com/tun2proxy/dns2socks/releases/download/v0.2.0/dns2socks-linux-arm64
    sudo mv $TMP_DNS /usr/local/bin/dns2socks
    sudo chmod +x /usr/local/bin/dns2socks
fi
echo "[+] dns2socks installed."

# --- Create TUN interface ---
echo "[*] Configuring TUN interface tun0..."
sudo ip tuntap add dev tun0 mode tun
sudo ip addr add 10.0.0.2/24 dev tun0
sudo ip link set dev tun0 up
sudo ip route add 0.0.0.0/1 dev tun0
sudo ip route add 128.0.0.0/1 dev tun0

# --- Start DNS over SOCKS ---
echo "[*] Launching dns2socks..."
sudo pkill dns2socks || true
sudo dns2socks 8.8.8.8 $HOST_IP $SOCKS_PORT 127.0.0.1:53 &

# --- Update DNS resolver ---
echo "[*] Updating /etc/resolv.conf for DNS..."
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# --- Start tun2socks ---
echo "[*] Launching tun2socks -> $HOST_IP:$SOCKS_PORT on $INTERFACE..."
sudo pkill tun2socks || true
sudo tun2socks -device tun0 -proxy socks5://$HOST_IP:$SOCKS_PORT -interface $INTERFACE &

# --- Wait and verify ---
sleep 3
echo "[*] Tunnel setup complete. Checking public IP..."
curl --interface tun0 https://ipinfo.io/ip || echo "Could not resolve IP via tunnel."

echo "[+] Tunnel is live!"
