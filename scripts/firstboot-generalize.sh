#!/bin/bash
set -eux

echo "=== First boot identity initialization ==="

# Ensure root filesystem is writable.
mount -o remount,rw / || true

# ------------------------------------------------------------
# Machine identity
# ------------------------------------------------------------

if [ ! -s /etc/machine-id ]; then
    systemd-machine-id-setup
fi

# ------------------------------------------------------------
# SSH host keys
# ------------------------------------------------------------

if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
    ssh-keygen -A
fi

# ------------------------------------------------------------
# Network
# ------------------------------------------------------------

systemctl enable NetworkManager
systemctl start NetworkManager

# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------

systemctl enable sshd
systemctl restart sshd

echo "=== First boot identity initialization complete ==="