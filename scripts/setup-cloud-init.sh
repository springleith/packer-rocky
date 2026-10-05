#!/bin/bash -eux

echo "=== Finalizing template for cloud-init ==="

if [ ! -f /etc/cloud/cloud.cfg ]; then
    echo "cloud-init not installed, aborting"
    exit 1
fi


# Datasource: NoCloud for Workstation (VMware datasource only runs on vSphere)
cat > /etc/cloud/cloud.cfg.d/99-datasource.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
EOF

# # Configure VMware datasource explicitly
# cat > /etc/cloud/cloud.cfg.d/99-vmware.cfg <<'EOF'
# datasource_list: [ VMware, OVF, None ]
# EOF

# Configure cloud-init for VMware guestinfo datasource
# do not allow cloud-init to override
cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<'EOF'
network: {config: disabled}
EOF



# Prevent network config from reverting on subsequent boots
# Prevent cloud-init from reverting network config after first boot
echo "manual_cache_clean: True" > /etc/cloud/cloud.cfg.d/99-manual.cache.cfg

# Clear cloud-init state so it runs fresh on first clone boot
cloud-init clean --logs


# Wipe machine-id (regenerated on boot)
# Truncate machine-id for clone uniqueness
truncate -s 0 /etc/machine-id

# Remove SSH host keys
# Clean SSH host keys so clones get unique ones
rm -f /etc/ssh/ssh_host_*


# Clear temporary files and history
rm -rf /tmp/* /var/tmp/*
export HISTSIZE=0


echo "=== Template cleanup complete ==="