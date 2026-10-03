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


source "vmware-iso" "rocky9" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  
  // hardware configuration
  vm_name      = "rocky01"
  guest_os_type = "rockylinux-64"
  cpus         = 2
  memory       = 2048
  disk_size    = 20480
  disk_type_id = "0"
  network_adapter_type = "e1000"

  // Http directory configuration
  http_directory = "http"
  boot_wait      = "10s"
  boot_command = [
    "<tab><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter>"
  ]

  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout  = "30m"
  shutdown_command = "sudo /sbin/shutdown -P now"
  headless         = true
}

build {
  sources = ["source.vmware-iso.rocky9"]

  provisioner "shell" {
    scripts = ["scripts/setup-cloud-init.sh"]
    execute_command = "echo 'packer' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
  }
}