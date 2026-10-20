# packer-rocky

### Stage 0: Build a golden image

run file: 
  build.ps1

#### Test SSH connection to image

ssh -i .\.secrets\packer_build_key `
    -o IdentitiesOnly=yes `
    packer@[your_image_ip_address]

### Stage 1: Create a server clone from image

run file:
  clone-one.ps1

#### Test SSH connection to created clone


ssh -i .\.secrets\packer_build_key `
    -o IdentitiesOnly=yes `
    packer@[your_clone_ip_address]
