#!/bin/bash
# Check Cellular Tunnel Status

TUN_NAME="tun0"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cellular Tunnel Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if pgrep -f tun2socks > /dev/null; then
    PID=$(pgrep -f tun2socks)
    UPTIME=$(ps -p $PID -o etime= | tr -d ' ')
    echo "✅ tun2socks running (PID: $PID, Uptime: $UPTIME)"
else
    echo "❌ tun2socks NOT running"
    echo ""
    echo "💡 Start with: ./setup-tunnel.sh"
    exit 1
fi

if ip link show $TUN_NAME &> /dev/null; then
    IP=$(ip addr show $TUN_NAME | grep -oP 'inet \K[\d.]+' | head -1)
    echo "✅ Interface $TUN_NAME exists ($IP)"
else
    echo "❌ Interface not found"
    exit 1
fi

if timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/1080" 2>/dev/null; then
    echo "✅ Every Proxy running"
else
    echo "⚠️  Every Proxy not detected"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Routes:"
ip route show | grep -E "default|$TUN_NAME" | sed 's/^/   /'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌍 Connection Test:"

PUBLIC_IP=$(timeout 10 curl -s --interface $TUN_NAME ipinfo.io/ip 2>/dev/null)

if [ -n "$PUBLIC_IP" ]; then
    echo "✅ Cellular working!"
    echo ""
    echo "   IP: $PUBLIC_IP"
    
    CARRIER=$(timeout 8 curl -s --interface $TUN_NAME ipinfo.io/org 2>/dev/null | sed 's/^AS[0-9]* //')
    [ -n "$CARRIER" ] && echo "   Carrier: $CARRIER"
    
    LOCATION=$(timeout 8 curl -s --interface $TUN_NAME ipinfo.io/city 2>/dev/null)
    [ -n "$LOCATION" ] && echo "   Location: $LOCATION"
else
    echo "❌ No connectivity"
    echo ""
    echo "Check: Every Proxy running? Cellular data on?"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Recent logs:"
tail -5 /tmp/tun2socks.log 2>/dev/null | sed 's/^/   /' || echo "   No logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
