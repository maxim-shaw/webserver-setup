#!/bin/bash
# Ubuntu Server 24.04 initial setup script
# Usage:
#   wget -qO- https://github.com/maxim-shaw/webserver-setup/raw/main/setup_ubuntu.sh | bash

set -e

echo "=== Updating system packages ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Installing base packages ==="
sudo apt install -y sudo openssh-server iptables bash curl

echo "=== Configuring SSH ==="
sudo systemctl enable ssh
sudo systemctl start ssh

SSHD_CONFIG="/etc/ssh/sshd_config"

# Harden SSH configuration
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"

if ! grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
    echo "PasswordAuthentication no" | sudo tee -a "$SSHD_CONFIG" >/dev/null
fi
if ! grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
    echo "PermitRootLogin yes" | sudo tee -a "$SSHD_CONFIG" >/dev/null
fi

sudo systemctl restart ssh

echo "=== Creating infra_si user ==="
if ! id infra_si >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash infra_si
    echo "User infra_si created."
fi

# Set up SSH folder and permissions
sudo mkdir -p /home/infra_si/.ssh
sudo chmod 700 /home/infra_si/.ssh
sudo touch /home/infra_si/.ssh/authorized_keys
sudo chmod 600 /home/infra_si/.ssh/authorized_keys
sudo chown -R infra_si:infra_si /home/infra_si/.ssh

# Add limited sudo rights (no password for infra deployment tools)
if ! sudo grep -q "infra_si" /etc/sudoers; then
    echo "infra_si ALL=(ALL) NOPASSWD: /usr/local/bin/deploy*, /usr/bin/microk8s*, /usr/bin/kubectl" | sudo tee -a /etc/sudoers >/dev/null
fi

echo "=== Setting up iptables firewall rules ==="
sudo bash -c 'cat > /etc/iptables/rules.v4' <<'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established/related
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH, HTTP, HTTPS
-A INPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT

# Drop everything else
COMMIT
EOF

# Install persistent iptables management
sudo apt install -y iptables-persistent
sudo systemctl enable netfilter-persistent
sudo netfilter-persistent save

echo "=== Setup complete! ==="
echo "You can now upload your SSH key to /home/infra_si/.ssh/authorized_keys"
