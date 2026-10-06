#!/bin/bash -eux

echo "=== Finalizing template for cloud-init ==="

if [ ! -f /etc/cloud/cloud.cfg ]; then
    echo "cloud-init not installed, aborting"
    exit 1
fi

##### DATASOURCE SECTION

# NoCloud for Workstation (VMware datasource only runs on vSphere)
cat > /etc/cloud/cloud.cfg.d/99-datasource.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
EOF

# Configure cloud-init for VMware guestinfo datasource
# do not allow cloud-init to override
cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<'EOF'
network: {config: disabled}
EOF


# Prevent network config from reverting on subsequent boots
# Prevent cloud-init from reverting network config after first boot
echo "manual_cache_clean: True" > /etc/cloud/cloud.cfg.d/99-manual.cache.cfg


# Config default user for clone step (cloud-init will create when booting with seed ISO)
cat > /etc/cloud/cloud.cfg.d/99-default-user.cfg <<'EOF'
system_info:
  default_user:
    name: rocky
    lock_passwd: true
    gecos: Rocky User
    groups: [wheel]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
EOF



##### SSH HARDENING: turn off password auth, only use key

cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
EOF

# Ensure crypto policy do not override (use DEFAULT instead of LEGACY)
update-crypto-policies --set DEFAULT


##### DELETE USER packer

# remove sudoers file from packer
rm -f /etc/sudoers.d/packer
# remove SSH key build from packer
rm -rf /home/packer/.ssh
# remove user packer completely
userdel -r packer 2>/dev/null || true



##### LOCK ROOT - do not allow root to log in with password
passwd -l root


##### RESET cloud-init state (before identity wiping out)
# Clear cloud-init state so it runs fresh on first clone boot
cloud-init clean --logs


##### WIPE IDENTITY - New one will be created every time cloning

# Wipe machine-id (regenerated on boot)
# Truncate machine-id for clone uniqueness
truncate -s 0 /etc/machine-id

# Remove SSH host keys
# Clean SSH host keys so clones get unique ones
rm -f /etc/ssh/ssh_host_*
rm -f /etc/ssh/ssh_host_*_key.pub

# Reset hostname
echo "localhost" > /etc/hostname
hostnamectl set-hostname localhost 2>/dev/null || true


##### FINAL CLEANING

# Clear temporary files and history
rm -rf /tmp/* /var/tmp/*
rm -f /root/.bash_history /home/*/.bash_history
export HISTSIZE=0
# delete old log (optional for lightweight template)
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true

echo "=== Template cleanup complete ==="