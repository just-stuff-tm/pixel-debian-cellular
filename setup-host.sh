#!/data/data/com.termux/files/usr/bin/bash
pkg install microsocks openssh -y

echo "-------------------------------------------------------"
echo "STEP 1: STARTING PROXY SERVER"
echo "-------------------------------------------------------"
# Start microsocks if not running
pgrep microsocks > /dev/null || microsocks -p 1080 &
termux-wake-lock & sshd
echo "[+] Proxy started on port 1080"
echo "[+] Wake-lock acquired (Termux won't sleep)"

echo ""
echo "-------------------------------------------------------"
echo "STEP 2: PREPARE PIXEL VM"
echo "-------------------------------------------------------"
echo "1. Open Pixel Settings > System > Developer Options"
echo "2. Linux development environment > Port control"
echo "3. Add Port 8022 (TCP) and turn it ON"
echo "4. Add port 1080 (socks5 internet access) and turn it on"
echo ""
echo "Now run the Guest Script With Wifi on your Pixel Linux Terminal"
echo "sudo apt install git && git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git && cd pixel-debian-cellular  chmod +x setup-guest.sh  sudo ./setup-guest.sh)."
