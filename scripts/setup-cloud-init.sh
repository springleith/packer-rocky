#!/bin/bash -eux

echo "=== Finalizing template for cloud-init ==="

# Ensure cloud-init is installed and enabled
dnf install -y cloud-init

# Configure VMware datasource explicitly
cat > /etc/cloud/cloud.cfg.d/99-vmware.cfg <<'EOF'
datasource_list: [ VMware, OVF, None ]
EOF

# Prevent network config from reverting on subsequent boots
echo "manual_cache_clean: True" > /etc/cloud/cloud.cfg.d/99-manual.cache.cfg

# Clear cloud-init state so it runs fresh on first clone boot
cloud-init clean --logs

# Wipe machine-id (regenerated on boot)
truncate -s 0 /etc/machine-id

# Remove SSH host keys
rm -f /etc/ssh/ssh_host_*

# Clear temporary files and history
rm -rf /tmp/* /var/tmp/*
export HISTSIZE=0

echo "=== Template cleanup complete ==="