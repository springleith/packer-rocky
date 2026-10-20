
#!/bin/bash
set -euxo pipefail

echo "=== Finalizing template for cloud-init ==="

if ! rpm -q cloud-init >/dev/null 2>&1; then
    echo "cloud-init is not installed; aborting"
    exit 1
fi

# 1. VMware Workstation clones will use a NoCloud seed ISO.
cat > /etc/cloud/cloud.cfg.d/99-datasource.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
EOF

# 2. Allow normal guest networking, including DHCP.
# Remove any old setting that disables cloud-init network configuration.
rm -f /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# Remove the previous custom cache setting if it exists.
rm -f /etc/cloud/cloud.cfg.d/99-manual.cache.cfg

# 3. Reset cloud-init state so each clone initializes from its own seed.
cloud-init clean --logs

# 4. Remove machine identity; the clone regenerates it on boot.
truncate -s 0 /etc/machine-id

# 5. Remove SSH host keys so every clone generates its own keys.
rm -f /etc/ssh/ssh_host_*

# 6. Reset hostname to a neutral template value.
echo "localhost" > /etc/hostname
hostnamectl set-hostname localhost 2>/dev/null || true


# 7. Remove Packer account and its build-time SSH credentials.
# rm -f /etc/sudoers.d/packer
# rm -rf /home/packer/.ssh
# userdel -r packer 2>/dev/null || true

# Lock root password login.
passwd -l root || true

# 8. Final cleanup.
rm -rf /tmp/* /var/tmp/*
rm -f /root/.bash_history /home/*/.bash_history
find /var/log -type f -name "*.log" \
    -exec truncate -s 0 {} \; 2>/dev/null || true

echo "=== Template cleanup complete ==="


echo "=== Verifying template cleanup ==="

rpm -q cloud-init
cat /etc/cloud/cloud.cfg.d/99-datasource.cfg
cat /etc/hostname
cat /etc/machine-id

# SSH host keys should not exist in the template.
if compgen -G "/etc/ssh/ssh_host_*" > /dev/null; then
    echo "ERROR: SSH host keys still exist"
    ls -l /etc/ssh/ssh_host_*
    exit 1
else
    echo "OK: SSH host keys have been removed"
fi

echo "=== Template cleanup complete ==="