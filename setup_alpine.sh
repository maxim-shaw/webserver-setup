#!/bin/sh
# Alpine Linux initial setup script
# Usage:
#   wget -qO- https://github.com/maxim-shaw/webserver-setup/raw/main/setup_alpine.sh | sh

set -e

echo "=== Updating system packages ==="
apk update && apk upgrade

echo "=== Installing base packages ==="
apk add --no-cache sudo openssh iptables iptables-openrc bash curl shadow snap

echo "=== Configuring SSH ==="
rc-update add sshd
rc-service sshd start

# Harden SSH configuration
SSHD_CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' $SSHD_CONFIG
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' $SSHD_CONFIG
grep -q "^PasswordAuthentication" $SSHD_CONFIG || echo "PasswordAuthentication no" >> $SSHD_CONFIG
grep -q "^PermitRootLogin" $SSHD_CONFIG || echo "PermitRootLogin yes" >> $SSHD_CONFIG

rc-service sshd restart

echo "=== Creating infra_si user ==="
if ! id infra_si >/dev/null 2>&1; then
    adduser -S -D -h /home/infra_si infra_si
    adduser infra_si wheel
fi

# Set up SSH folder and permissions
mkdir -p /home/infra_si/.ssh
chmod 700 /home/infra_si/.ssh
touch /home/infra_si/.ssh/authorized_keys
chmod 600 /home/infra_si/.ssh/authorized_keys
chown -R infra_si:wheel /home/infra_si/.ssh

# Add limited sudo rights
if ! grep -q "infra_si" /etc/sudoers; then
    #echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/deploy*, /usr/bin/microk8s*, /usr/bin/kubectl" >> /etc/sudoers
fi

# Make infra_si user an interactive user for ssh shell commands
sed -i '/^infra_si:/s/^infra_si:!*/infra_si:*/' /etc/shadow

echo "=== Setting up iptables firewall rules ==="
cat <<'EOF' > /etc/iptables/rules-save
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

rc-update add iptables
rc-service iptables save
rc-service iptables start

echo "=== Setup complete! ==="
echo "You can now upload your SSH key to /home/infra_si/.ssh/authorized_keys"
