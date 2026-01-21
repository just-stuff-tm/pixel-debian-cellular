#!/bin/bash
# Stop Cellular Tunnel

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛑 Stopping Cellular Tunnel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if pgrep -f tun2socks > /dev/null; then
    echo "[*] Stopping tun2socks..."
    pkill -f tun2socks
    sleep 1
    echo "[+] Process stopped ✓"
else
    echo "[!] tun2socks not running"
fi

if ip link show tun0 &> /dev/null; then
    echo "[*] Removing tunnel interface..."
    ip link delete tun0 2>/dev/null
    echo "[+] Interface removed ✓"
fi

ip route del default dev tun0 2>/dev/null || true

echo ""
echo "✅ Tunnel stopped"
echo "📱 Debian terminal back to WiFi-only"
echo ""

if timeout 5 curl -s ipinfo.io/ip &> /dev/null; then
    CURRENT_IP=$(curl -s --max-time 5 ipinfo.io/ip)
    echo "🌍 Current IP: $CURRENT_IP (WiFi)"
else
    echo "⚠️  No internet - connect to WiFi"
fi
