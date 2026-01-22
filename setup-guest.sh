#!/bin/bash

# -----------------------------
# PIXEL DEBIAN GUEST SETUP
# -----------------------------

# 1. Detect Termux Gateway IP
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')

if [ -z "$GATEWAY_IP" ]; then
    echo "Error: Could not detect Gateway. Ensure Linux Network is ON."
    exit 1
fi

echo "Setting up system-wide bridge to Termux at $GATEWAY_IP..."

# 2. System-wide proxy configuration for environment
PROXY="socks5h://$GATEWAY_IP:1080"

# Persist proxy variables for all users
for f in /etc/environment /etc/profile /etc/bash.bashrc; do
    sudo sed -i '/ALL_PROXY/d' $f
    sudo sed -i '/all_proxy/d' $f
    sudo sed -i '/HTTPS_PROXY/d' $f
    sudo sed -i '/https_proxy/d' $f
    echo "ALL_PROXY=\"$PROXY\"" | sudo tee -a $f > /dev/null
    echo "all_proxy=\"$PROXY\"" | sudo tee -a $f > /dev/null
    echo "HTTPS_PROXY=\"$PROXY\"" | sudo tee -a $f > /dev/null
    echo "https_proxy=\"$PROXY\"" | sudo tee -a $f > /dev/null
done

# Export for current shell immediately
export ALL_PROXY=$PROXY
export all_proxy=$PROXY
export HTTPS_PROXY=$PROXY
export https_proxy=$PROXY

echo "[+] System-wide proxy set to $PROXY"

# 3. Configure APT to use the proxy
sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null << EOF
Acquire::http::Proxy "$PROXY/";
Acquire::https::Proxy "$PROXY/";
Acquire::socks::proxy "$PROXY/";
EOF

echo "[+] APT proxy configured"

# 4. Install and configure SSH server
sudo apt update && sudo apt install -y openssh-server

# Ensure SSH uses port 8022
if grep -q "^#Port 22" /etc/ssh/sshd_config; then
    sudo sed -i 's/^#Port 22/Port 8022/' /etc/ssh/sshd_config
elif grep -q "^Port " /etc/ssh/sshd_config; then
    sudo sed -i 's/^Port .*/Port 8022/' /etc/ssh/sshd_config
else
    echo "Port 8022" | sudo tee -a /etc/ssh/sshd_config
fi

# Ensure SSH runtime directory exists
sudo mkdir -p /run/sshd

# Start SSH server
if command -v systemctl &>/dev/null; then
    sudo systemctl enable ssh
    sudo systemctl restart ssh
else
    sudo /usr/sbin/sshd -D -p 8022 &
fi

# 5. Get Debian VM IP
VM_IP=$(ip addr show enp0s12 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

echo "-------------------------------------------------------"
echo "PIXEL GUEST SETUP COMPLETE"
echo "-------------------------------------------------------"
echo "[+] System-wide Internet via $PROXY"
echo "[+] SSH Server: Running on port 8022"
echo ""
echo "TO CONNECT FROM TERMUX:"
echo "ssh -p 8022 droid@$VM_IP"
echo ""
echo "Test system-wide connectivity immediately:"
echo "curl https://ifconfig.me"
echo "-------------------------------------------------------"
