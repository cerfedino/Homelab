# Home Assistant OS


resource "proxmox_virtual_environment_vm" "haos" {
  depends_on = [
    proxmox_network_linux_bridge.network_internal,
    proxmox_network_linux_bridge.network_lan,
  ]

  vm_id       = var.vm_haos.vm_id
  name        = var.vm_haos.display_name
  description = "Managed by OpenTofu"
  node_name   = var.vm_haos.node_name

  stop_on_destroy = true
  on_boot         = true

  bios          = "ovmf"
  boot_order    = ["scsi0"]
  tablet_device = false

  agent {
    enabled = true
  }

  tags = ["tofu"]

  cpu {
    cores = var.vm_haos.cores
    type  = "qemu64"
  }

  memory {
    dedicated = var.vm_haos.memory
  }

  disk {
    datastore_id = var.vm_haos.datastore
    interface    = "scsi0"
    size         = var.vm_haos.disk_size
    cache        = "writeback"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
  }

  network_device {
    bridge      = var.network_lan.bridge
    mac_address = var.vm_haos.mac_lan
  }

  network_device {
    bridge      = var.network_internal.bridge
    mac_address = var.vm_haos.mac_internal
  }

  # Zigbee/Z-Wave stick
  usb {
    host = var.vm_haos.usb_host
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
  }
}
