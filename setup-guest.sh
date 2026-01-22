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

# 4. Install and configure SSH Server
sudo apt update && sudo apt install -y openssh-server

# Ensure Port 8022 is set in sshd_config
if grep -q "^#Port 22" /etc/ssh/sshd_config; then
    sudo sed -i 's/^#Port 22/Port 8022/' /etc/ssh/sshd_config
elif grep -q "^Port " /etc/ssh/sshd_config; then
    sudo sed -i 's/^Port .*/Port 8022/' /etc/ssh/sshd_config
else
    echo "Port 8022" | sudo tee -a /etc/ssh/sshd_config
fi

# Enable password login temporarily (so key can be added)
sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure SSH runtime directory exists
sudo mkdir -p /run/sshd

# Start SSH server
if command -v systemctl &>/dev/null; then
    sudo systemctl enable ssh
    sudo systemctl restart ssh
else
    sudo /usr/sbin/sshd -D -p 8022 &
fi

# 5. Setup Termux public key for passwordless SSH
# Assumes Termux public key is in ~/termux_id_ed25519.pub
TERMUX_KEY_FILE="$HOME/termux_id_ed25519.pub"
if [ -f "$TERMUX_KEY_FILE" ]; then
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    grep -qxF "$(cat $TERMUX_KEY_FILE)" ~/.ssh/authorized_keys || \
        cat $TERMUX_KEY_FILE >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    echo "[*] Termux public key installed for passwordless login"
else
    echo "[!] Termux public key not found at $TERMUX_KEY_FILE"
    echo "    Please copy your Termux public key to this file and re-run the script"
fi

# 6. Disable password login now that key is added (more secure)
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh || sudo /usr/sbin/sshd -D -p 8022 &

# 7. Get the VM's current IP for the user
VM_IP=$(ip addr show enp0s12 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

echo "-------------------------------------------------------"
echo "PIXEL GUEST SETUP COMPLETE"
echo "-------------------------------------------------------"
echo "[+] Internet: Configured via $GATEWAY_IP:1080"
echo "[+] SSH Server: Running on port 8022 with key-based login"
echo ""
echo "TO CONNECT FROM TERMUX:"
echo "Run: ssh -p 8022 droid@$VM_IP"
echo ""
echo "NOTE: If internet stops working after a reboot, re-run"
echo "this script to update the Gateway IP."
echo "-------------------------------------------------------"
