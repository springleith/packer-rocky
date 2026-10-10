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

variable "username" {
  type        = string
  description = "The username to connect to SSH"
  default     = "root"
}

variable "password" {
  type        = string
  description = "A plaintext password to authenticate with SSH"
  default     = "123456"
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
  

  // Boot configuration
  boot_command = [
    "<up><wait>",
    "<tab><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter>"
  ]
  boot_wait    = "10s"


  // Communicator configuration
  communicator = "ssh"
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "30m"

  // Output configuration
  output_directory = "template"

  // Export configuration
  format          = "vmx"
  skip_compaction = false

}

build {
  sources = ["source.vmware-iso.rocky9"]

  provisioner "shell" {
    scripts = ["scripts/provisioning.sh"]
    execute_command = "echo 'packer' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
  }
}