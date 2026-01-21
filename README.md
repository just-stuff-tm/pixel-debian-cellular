# Pixel Debian Terminal Cellular Access

Enable cellular data for Google Pixel's experimental Debian terminal. **WiFi only required for initial setup.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Pixel](https://img.shields.io/badge/platform-Google%20Pixel-blue.svg)](https://store.google.com/product/pixel)
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

## 🎯 The Problem

Google Pixel's experimental Debian terminal (Android 14+) **can only access the internet via WiFi by default**. It cannot use cellular data.

This project solves that by routing terminal traffic through your Pixel's cellular connection using tun2socks.

## ✨ The Solution

- 📱 **WiFi only needed once** - for initial tun2socks download
- 🚀 **After setup** - Use cellular data even with WiFi disabled
- 🔧 **No external devices** - Everything runs on your Pixel
- 🌍 **Full cellular access** - All terminal apps use mobile data

## 🚀 Quick Start

```bash
# ONE-TIME SETUP (requires WiFi):

# 1. Install Every Proxy from Play Store
#    Configure: SOCKS5, port 1080, bind 127.0.0.1
#    Tap START

# 2. In Debian Terminal (connect to WiFi first):
git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git
cd pixel-debian-cellular
chmod +x setup-tunnel.sh
./setup-tunnel.sh

# 3. Done! WiFi now optional:
curl ipinfo.io/ip  # Shows cellular IP
# You can now disable WiFi - terminal keeps cellular internet
```

## 📦 Prerequisites

### Hardware
- **Google Pixel device** (Pixel 3+, tested on Pixel 6/7/8)
- Active cellular data plan

### Software

1. **Debian Terminal** (Android 14+)
   ```
   Settings → System → Developer options → Linux terminal
   Enable and download
   ```

2. **Every Proxy** (Android app)
   - Install: [Play Store Link](https://play.google.com/store/apps/details?id=com.gorillasoftware.everyproxy)
   - Free, no account needed
   - Bridges cellular to container

3. **WiFi Connection** (one-time only)
   - Needed to download tun2socks
   - Can disable after setup

## 📥 Installation

### Step 1: Enable Debian Terminal

**On your Pixel:**
```
1. Settings → System → About phone
2. Tap "Build number" 7 times → Developer options enabled
3. Settings → System → Developer options
4. Scroll down to "Linux terminal"
5. Enable → Wait for download (requires WiFi)
6. Open "Terminal" app from app drawer
```

### Step 2: Setup Every Proxy

1. Install **[Every Proxy](https://play.google.com/store/apps/details?id=com.gorillasoftware.everyproxy)** from Play Store
2. Configure:
   - **Server Type:** SOCKS5
   - **Port:** 1080
   - **Bind Address:** 127.0.0.1 (NOT 0.0.0.0)
   - **Authentication:** None
3. Tap **START**
4. Verify notification: "Proxy server running on port 1080"

### Step 3: Run Setup

```bash
# In Debian Terminal (connected to WiFi):
git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git
cd pixel-debian-cellular
chmod +x setup-tunnel.sh
./setup-tunnel.sh
```

### Step 4: Test Cellular Access

```bash
# Check IP (should show cellular)
curl ipinfo.io/ip

# Disable WiFi and test again
curl ipinfo.io/ip
# Still works! Using cellular.
```

## 🎮 Usage

### Start Cellular Access
```bash
./setup-tunnel.sh
```

### Check Status
```bash
./check-status.sh
```

### Stop Cellular
```bash
./stop-tunnel.sh
```

## 🔧 Troubleshooting

### "Cannot connect to SOCKS5 proxy"

**Solution:**
1. Verify Every Proxy is running
2. Check settings: SOCKS5, port 1080, bind 127.0.0.1
3. Test: `curl -x socks5://127.0.0.1:1080 ipinfo.io/ip`

### "No internet during setup"

**Solution:**
1. Connect to WiFi
2. Verify: `ping -c 3 google.com`
3. Run setup again

### "Tunnel created but no connection"

**Solution:**
1. Check cellular data is enabled
2. Restart Every Proxy
3. View logs: `tail -f /tmp/tun2socks.log`

## 🙏 Credits

### Core Technology
- **[xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks)** - High-performance tun2socks (Go)
- **[Every Proxy](https://play.google.com/store/apps/details?id=com.gorillasoftware.everyproxy)** - SOCKS5 server for Android

### Alternative Solutions
- **[Shadowsocks Android](https://github.com/shadowsocks/shadowsocks-android)** - Encrypted proxy
- **[badvpn](https://github.com/ambrop72/badvpn)** - Original C implementation

## 📄 License

MIT License - See [LICENSE](LICENSE) file

## 🤝 Contributing

Contributions welcome! Submit issues and pull requests.

---

**Made for Pixel Debian Terminal users** 📱💻
