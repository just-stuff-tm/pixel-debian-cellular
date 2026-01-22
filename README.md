# Pixel Debian Terminal Cellular Access

Enable cellular data for Google Pixel's experimental Debian Terminal. One time wifi setup required  on Debian Terminal if installing using git.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Pixel](https://img.shields.io/badge/platform-Google%20Pixel-blue.svg)](https://store.google.com/product/pixel)
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

## 🎯 The Problem

Google Pixel's experimental Debian terminal (Android 14+) **can only access the internet via WiFi by default**. It cannot use cellular data.

This project solves that by routing terminal traffic through your Pixel's cellular connection using Termux .

## ✨ The Solution

- 🚀 **After setup** - Use cellular data even with WiFi disabled.
- 🔧 **No external devices** - Everything runs on your Pixel and You can ssh into the terminal via Termux for a user friendly experience.
- 🌍 **Full cellular access** - All terminal apps use mobile data

## 🚀 Quick Start on Termux

```bash
# ONE-TIME SETUP:

# 1. Install Termux and run script below. 
```
```bash
# 2. In Termux:
pkg install git -y

git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git
cd pixel-debian-cellular

chmod +x setup-host.sh

./setup-host.sh

```
```bash
# 3. Follow instructions provided by Termux
```

## 📦 Quick Start On Pixel

### Hardware
- **Google Pixel device** (Pixel 3+, tested on Pixel 6/7/8)
- Active cellular data plan

### Software

1. **Debian Terminal** (Android 14+)
   ```
   Settings → System → Developer options → Linux terminal
   Enable and download
   ```

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

```bash
# In Debian Terminal (connected to WiFi):
sudo apt install git &&
git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git &&
cd pixel-debian-cellular &&
chmod +x setup-guest.sh &&
sudo ./setup-guest.sh
```

### Step 4: Test Cellular Access

```bash
# Check IP (should show cellular)
curl ipinfo.io/ip

# Disable WiFi and test again
curl ipinfo.io/ip
# Still works! Using cellular.
```

## 📄 License

MIT License - See [LICENSE](LICENSE) file

## 🤝 Contributing

Contributions welcome! Submit issues and pull requests.

---

**Made for Pixel Debian Terminal users** 📱💻

- **[Discord](https://discord.gg/TbWRrDgjGQ)**
