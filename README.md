# Pixel Debian Terminal Cellular Access

Enable cellular data for Google Pixel's experimental Debian Terminal. One-time WiFi setup required on Debian Terminal if installing using git.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)  
[![Platform: Pixel](https://img.shields.io/badge/platform-Google%20Pixel-blue.svg)](https://store.google.com/product/pixel)  
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

## 🎯 The Problem

Google Pixel's experimental Debian terminal (Android 14+) **can only access the internet via WiFi by default**. It cannot use cellular data.

This project solves that by routing terminal traffic through your Pixel's cellular connection using **Termux**.

## ✨ The Solution

- 🚀 **After setup** - Use cellular data even with WiFi disabled.  
- 🔧 **No external devices** - Everything runs on your Pixel and you can SSH into Debian via Termux.  
- 🌍 **Full cellular access** - All terminal apps use mobile data via SOCKS5 proxy.  

## 🚀 Quick Start on Termux (Host)

```bash
# ONE-TIME SETUP:
pkg install git -y

git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git
cd pixel-debian-cellular

chmod +x setup-host.sh
./setup-host.sh
```

- The script will automatically:  
  - Start a SOCKS5 proxy on **port 1080**  
  - Start SSH server on **port 8022**  
  - Generate a Termux SSH key if missing  
  - Output a **copy-paste block** for Debian to add the Termux key  

## 📦 Quick Start on Debian (Guest)

### Hardware
- **Google Pixel device** (Pixel 3+, tested on Pixel 6/7/8)  
- Active cellular data plan  

### Software
1. **Debian Terminal** (Android 14+)  
   ```
   Settings → System → Developer options → Linux terminal
   Enable and download
   ```

### Step 1: Run Debian Guest Setup

- Make sure WiFi is active for initial setup.  
- **Copy the command block** provided by Termux (from `setup-host.sh`) into Debian Terminal and run it.  
- This will automatically:  
  - Configure SSH on port **8022**  
  - Configure internet via SOCKS5 proxy **1080**  
  - Install necessary packages (git, etc.)  
- **No password entry required** (Termux key handles authentication).  

**Example Termux-provided copy-paste block:**

```bash
sudo apt install git -y && \
git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git && \
cd pixel-debian-cellular && \
mkdir -p ~/.ssh && \
echo '<TERMX_PUB_KEY>' >> ~/.ssh/authorized_keys && \
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && \
chmod +x setup-guest.sh && \
sudo ./setup-guest.sh
```

> The `<TERMX_PUB_KEY>` will automatically be filled by Termux during setup.

### Step 2: Test Cellular Access

```bash
# Check public IP (should reflect cellular network)
curl ipinfo.io/ip

# Disable WiFi and test again
curl ipinfo.io/ip
# Still works! Cellular is active.
```

## ⚙️ Notes

- Debian script **does not handle SSH keys** — Termux manages key generation and copy-paste.  
- If the VM is rebooted, re-run the Debian guest script to update the proxy configuration if needed.  
- SSH login is passwordless after running the Termux copy-paste command.

## 📄 License

MIT License - See [LICENSE](LICENSE) file

## 🤝 Contributing

Contributions welcome! Submit issues and pull requests.  

**Made for Pixel Debian Terminal users** 📱💻  

- **[Discord](https://discord.gg/TbWRrDgjGQ)**
- 
