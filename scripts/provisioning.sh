#!/usr/bin/env bash


# Description : Creating a virtual machine template under Rocky Linux 9 from ISO file with Packer using VMware Workstation
# Author : Yoann LAMY <https://github.com/ynlamy/packer-rockylinux9>
# Licence : GPLv3

set -Eeuo pipefail

echo "Updating the system..."
dnf -y -q update &> /dev/null

echo "Installing packages..."
dnf -y -q install open-vm-tools mlocate net-tools unzip wget &> /dev/null

cat > /etc/ssh/sshd_config.d/00-packer-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

# Validate the configuration before reloading SSH
sshd -t

# Show the effective settings
sshd -T | grep -E '^(passwordauthentication|pubkeyauthentication|permitrootlogin|kbdinteractiveauthentication) '

systemctl reload sshd

echo "Deleting the files ks.cfg..."
rm -f /root/anaconda-ks.cfg /root/original-ks.cfg

echo "Cleaning dnf cache..."
dnf -y -q clean all &> /dev/null

echo "Deleting temporary files..."
rm -fr /tmp/*

echo "Clearing the history..."
history -c