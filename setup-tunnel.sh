#!/bin/bash
set -e

echo "------------------------------------------"
echo "🚀 Pixel VM SOCKS Tunnel Installer"
echo "------------------------------------------"

# --- Dependencies ---
echo "[*] Installing dependencies..."
sudo apt update || true
sudo apt install -y git curl unzip iproute2 procps gcc

# --- Detect network interface ---
INTERFACE="enp0s12"
echo "[*] Using interface: $INTERFACE"

# --- Detect Android host IP automatically ---
ANDROID_HOST=$(ip route | grep default | awk '{print $3}')
if [ -z "$ANDROID_HOST" ]; then
    read -p "[*] Could not detect Android host automatically. Enter host IP manually: " ANDROID_HOST
fi
echo "[*] Detected Android host: $ANDROID_HOST"

# --- Set default SOCKS port ---
SOCKS_PORT=1080
echo "[*] Using SOCKS port: $SOCKS_PORT"

# --- Install tun2socks ---
if ! command -v tun2socks &> /dev/null; then
    echo "[*] Installing tun2socks..."
    curl -L -o /tmp/tun2socks.zip "https://github.com/tun2proxy/tun2socks/releases/download/v4.0.6/tun2socks-linux-arm64.zip"
    unzip /tmp/tun2socks.zip -d /tmp/
    sudo mv /tmp/tun2socks-linux-arm64 /usr/local/bin/tun2socks
    sudo chmod +x /usr/local/bin/tun2socks
fi
echo "[+] tun2socks installed."

# --- Install dns2socks ---
if ! command -v dns2socks &> /dev/null; then
    echo "[*] Installing dns2socks..."
    curl -L -o /tmp/dns2socks.zip "https://release-assets.githubusercontent.com/github-production-release-asset/771063522/f3a34092-7553-4b3f-bd67-74f565d77676?sp=r&sv=2018-11-09&sr=b&spr=https&se=2026-01-21T08%3A26%3A25Z&rscd=attachment%3B+filename%3Ddns2socks-aarch64-unknown-linux-gnu.zip"
    unzip /tmp/dns2socks.zip -d /tmp/
    sudo mv /tmp/dns2socks /usr/local/bin/
    sudo chmod +x /usr/local/bin/dns2socks
fi
echo "[+] dns2socks installed."

# --- Configure TUN interface ---
TUN_IF="tun0"
sudo ip tuntap add dev $TUN_IF mode tun || true
sudo ip addr add 10.0.0.2/24 dev $TUN_IF || true
sudo ip link set dev $TUN_IF up
sudo ip route add default dev $TUN_IF || true
echo "[*] TUN interface $TUN_IF configured."

# --- Start DNS over SOCKS ---
sudo dns2socks 127.0.0.1:$SOCKS_PORT 8.8.8.8 127.0.0.1:5353 &
echo "[*] DNS over SOCKS started on 127.0.0.1:5353"

# --- Update DNS resolver ---
sudo sh -c 'echo "nameserver 127.0.0.1" > /etc/resolv.conf'

# --- Start tun2socks ---
sudo tun2socks -device $TUN_IF -proxy socks5://$ANDROID_HOST:$SOCKS_PORT -interface $INTERFACE &
echo "[*] tun2socks started -> $ANDROID_HOST:$SOCKS_PORT on $INTERFACE"

echo "[+] Tunnel setup complete! Your VM traffic is now routed through the Android host SOCKS server."
