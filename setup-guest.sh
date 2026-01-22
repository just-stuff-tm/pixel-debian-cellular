#!/bin/bash

# 1. Automatically detect the Termux Gateway IP
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')

if [ -z "$GATEWAY_IP" ]; then
    echo "Error: Could not detect Gateway. Ensure Linux Network is ON."
    exit 1
fi

echo "Setting up bridge to Termux at $GATEWAY_IP..."

# 2. Set Persistent Environment Variables for Internet Access
sed -i '/ALL_PROXY/d' ~/.bashrc
echo "export ALL_PROXY=socks5h://$GATEWAY_IP:1080" >> ~/.bashrc
echo "export all_proxy=socks5h://$GATEWAY_IP:1080" >> ~/.bashrc

# 3. Set Persistent APT Proxy
sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null << proxyEOF
Acquire::http::Proxy "socks5h://$GATEWAY_IP:1080/";
Acquire::https::Proxy "socks5h://$GATEWAY_IP:1080/";
Acquire::socks::proxy "socks5h://$GATEWAY_IP:1080/";
proxyEOF

# 4. Set Up SSH Server for Termux Access
sudo apt update && sudo apt install openssh-server -y
sudo sed -i 's/#Port 22/Port 8022/' /etc/ssh/sshd_config
sudo mkdir -p /run/sshd
sudo /usr/sbin/sshd -p 8022

# 5. Get the VM's current IP for the user
VM_IP=$(ip addr show enp0s12 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

echo "-------------------------------------------------------"
echo "PIXEL GUEST SETUP COMPLETE"
echo "-------------------------------------------------------"
echo "[+] Internet: Configured via $GATEWAY_IP:1080"
echo "[+] SSH Server: Running on port 8022"
echo ""
echo "TO CONNECT FROM TERMUX:"
echo "Run: ssh -p 8022 droid@$VM_IP"
echo ""
echo "NOTE: If internet stops working after a reboot, re-run"
echo "this script to update the Gateway IP."
echo "-------------------------------------------------------"
