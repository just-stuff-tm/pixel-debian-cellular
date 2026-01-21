#!/bin/bash
echo "------------------------------------------"
echo "🚀 Pixel Linux Tunnel Installer"
echo "------------------------------------------"

# 1️⃣ Install dependencies
echo "[*] Installing dependencies..."
sudo apt update && sudo apt install -y git curl unzip iproute2 procps adb

# 2️⃣ Ensure tun2socks is installed
if ! command -v tun2socks >/dev/null 2>&1; then
    echo "[*] Installing tun2socks..."
    ARCH=$(uname -m)
    if [[ $ARCH == "aarch64" ]]; then
        URL="https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-arm64.zip"
    else
        URL="https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-amd64.zip"
    fi
    curl -L -o /tmp/tun2socks.zip "$URL"
    unzip /tmp/tun2socks.zip -d /tmp
    sudo mv /tmp/tun2socks-linux* /usr/local/bin/tun2socks
    sudo chmod +x /usr/local/bin/tun2socks
fi
echo "[+] tun2socks installed."

# 3️⃣ Ensure dns2socks is installed
if ! command -v dns2socks >/dev/null 2>&1; then
    echo "[*] Installing dns2socks..."
    git clone https://github.com/txthinking/dns2socks.git /tmp/dns2socks
    gcc /tmp/dns2socks/dns2socks.c -o /tmp/dns2socks/dns2socks
    sudo mv /tmp/dns2socks/dns2socks /usr/local/bin/dns2socks
    sudo chmod +x /usr/local/bin/dns2socks
fi
echo "[+] dns2socks installed."

# 4️⃣ Select main interface
IFACE=$(ip route get 1 | awk '{print $5; exit}')
echo "[*] Using interface: $IFACE"

# 5️⃣ Ask for Pixel SOCKS server
read -p "[?] Enter Pixel SOCKS IP: " SOCKS_IP
read -p "[?] Enter SOCKS port [1080]: " SOCKS_PORT
SOCKS_PORT=${SOCKS_PORT:-1080}

# 6️⃣ Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# 7️⃣ Start dns2socks for DNS resolution
echo "[*] Starting dns2socks for proxy DNS..."
sudo dns2socks "$SOCKS_IP" "$SOCKS_PORT" 8.8.8.8 127.0.0.1:53 &
DNS_PID=$!

# 8️⃣ Start tun2socks
echo "[*] Starting tun2socks tunnel..."
sudo tun2socks -device tun0 -interface "$IFACE" -proxy "socks5://$SOCKS_IP:$SOCKS_PORT" &
TUN_PID=$!

# 9️⃣ Wait for tun0
echo "[*] Waiting for tun0 to come up..."
while ! ip link show tun0 >/dev/null 2>&1; do
    sleep 1
done
echo "[+] TUN interface tun0 is ready."

# 10️⃣ Set default route via tun0
sudo ip route add default dev tun0

# 11️⃣ Use dns2socks for DNS
echo "[*] Pointing system DNS to dns2socks..."
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
echo "[+] DNS configured via dns2socks"

# 12️⃣ Test connectivity
echo "[*] Testing tunnel connectivity..."
curl --interface tun0 -s https://ipinfo.io/ip

echo "[+] Tunnel setup complete."
echo "[*] tun2socks PID: $TUN_PID"
echo "[*] dns2socks PID: $DNS_PID"
echo "[*] To stop tunnel: sudo kill $TUN_PID $DNS_PID"
