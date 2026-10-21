# packer-rocky

### Build a golden image

run file: 
  build.ps1

#### Test SSH connection to image

ssh -i .\.secrets\packer_build_key `
    -o IdentitiesOnly=yes `
    packer@[your_image_ip_address]

### Create a cloned server from image

On your WSL, ensure genisoimage installed:
apt update
apt install genisoimage

run file:
  clone-one.ps1

#### Test SSH connection to created clone


ssh -i .\.secrets\packer_build_key `
    -o IdentitiesOnly=yes `
    packer@[your_clone_ip_address]

### Run ansible playbook for basic configuration management
On ansible/inventory/hosts, replace your private path
ansible_host=[your_clone_ip_address] ansible_ssh_private_key_path=[your_own_path]

run file:
  site.yml

