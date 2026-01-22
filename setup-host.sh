#!/data/data/com.termux/files/usr/bin/bash

# -----------------------------
# PIXEL TERMUX HOST SETUP
# -----------------------------

# Install required packages
pkg install microsocks openssh -y

echo "-------------------------------------------------------"
echo "STEP 1: STARTING PROXY SERVER AND SSH"
echo "-------------------------------------------------------"
# Start microsocks if not running
pgrep microsocks > /dev/null || microsocks -p 1080 &
termux-wake-lock &
pgrep sshd > /dev/null || sshd
echo "[+] Proxy started on port 1080"
echo "[+] Wake-lock acquired (Termux won't sleep)"
echo "[+] SSH server started in Termux"

# -----------------------------
# Generate Termux SSH key if missing
# -----------------------------
echo ""
echo "-------------------------------------------------------"
echo "STEP 2: ENSURING TERMUX SSH KEY EXISTS"
echo "-------------------------------------------------------"

KEY_FILE="$HOME/.ssh/id_ed25519"
PUB_KEY_FILE="$HOME/.ssh/id_ed25519.pub"

mkdir -p ~/.ssh
if [ ! -f "$KEY_FILE" ]; then
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N ""
    echo "[+] Generated new SSH key at $KEY_FILE"
else
    echo "[+] SSH key already exists at $KEY_FILE"
fi

# Read the public key
TERMUX_PUB_KEY=$(cat "$PUB_KEY_FILE")

# -----------------------------
# Debian copy-paste block
# -----------------------------
echo ""
echo "-------------------------------------------------------"
echo "STEP 3: COPY-PASTE THIS ON DEBIAN GUEST"
echo "-------------------------------------------------------"
echo ""
echo "sudo apt install git -y && \\"
echo "git clone https://github.com/just-stuff-tm/pixel-debian-cellular.git && \\"
echo "cd pixel-debian-cellular && \\"
echo "mkdir -p ~/.ssh && \\"
echo "echo '$TERMUX_PUB_KEY' >> ~/.ssh/authorized_keys && \\"
echo "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && \\"
echo "chmod +x setup-guest.sh && \\"
echo "sudo ./setup-guest.sh"
echo ""
echo "This will automatically:"
echo "- Configure SSH on port 8022"
echo "- Install your Termux public key for passwordless login"
echo "- Configure internet access via SOCKS5 proxy on port 1080"
echo ""
echo "Once done, you can SSH from Termux into Debian without a password:"
echo "ssh -p 8022 droid@<DEBIAN_VM_IP>"
echo "-------------------------------------------------------"
