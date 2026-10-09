#https://developer.hashicorp.com/packer/integrations/vmware/vmware/latest/components/builder/iso

packer {
  required_version = ">= 1.7.0"
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "iso_url" {
  type    = string
  description = "A URL to the ISO file"
  default = "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9-latest-x86_64-minimal.iso"
}

variable "iso_checksum" {
  type    = string
  description = "The checksum for the ISO file"
  default = "SHA256:d338032cd1cdd41c67139f2f71b4c832c8e4a21943106519db9c7137df7a63d4" # Replace with actual checksum for production
}

variable "headless" {
  type        = bool
  description = "When this value is set to true, the machine will start without a console"
  default     = false
}

variable "vm_name" {
  type        = string
  description = "This is the name of the new virtual machine"
  default     = "rocky-base"
}

# ssh use a temporary key to log in instead using username and password
variable "ssh_public_key" {
  type    = string
  description = "Public key matching packer_build_key"
  default = env("PACKER_SSH_PUBLIC_KEY")
}

source "vmware-iso" "rocky9" {
  
  // ISO configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  
  // hardware configuration
  vm_name      = var.vm_name
  vmdk_name = var.vm_name
  firmware             = "bios"
  version              = 20
  guest_os_type = "rockylinux-64"
  cpus         = 2
  // vmx_data = {"numvcpus" = "2"}
  memory       = 2048
  disk_size    = 20480
  disk_adapter_type    = "scsi"
  disk_type_id = "0"
  network              = "nat"
  network_adapter_type = "e1000"
  sound                = false
  usb                  = false

  // Run configuration
  headless = var.headless

  // Shutdown configuration
  shutdown_command = "systemctl poweroff"

  // Http directory configuration
  http_directory = "http"
  // http_content = {
  //"/ks.cfg"         = file("${path.root}/http/ks.cfg")
   // "/packer_key.pub" = var.ssh_public_key
  //}
  
  // Boot configuration
  boot_command = [
    "<up><wait>",
    "<tab><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter>"
  ]
  boot_wait    = "10s"


  // Communicator configuration
  // packer will generate temporary SSH key after each time building
  // this key is injected into VM through ks.cfg (watch http/ks.cfg)
  // after provision has been done, packer automatically removes the public key from authorized_keys
  communicator = "ssh"
  ssh_username = "packer"
  ssh_password = "packer"
  //ssh_private_key_file      = "packer_build_key" 
  ssh_timeout  = "30m"
  ssh_handshake_attempts    = 20
  ssh_clear_authorized_keys = true

  // Output configuration
  output_directory = "template"

  // Export configuration
  skip_compaction = false

}

build {
  sources = ["source.vmware-iso.rocky9"]

  # step 1: Basic provisioning (update, install tools)
  provisioner "shell" {
    scripts = ["scripts/provisioning.sh"]
    execute_command = "echo 'packer' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
  }

  # step 2: Finalize template (wipe identity, delete user packer, lock root)
  provisioner "shell" {
    scripts = ["scripts/setup-cloud-init.sh"]
    execute_command = "echo 'packer' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
  }
}