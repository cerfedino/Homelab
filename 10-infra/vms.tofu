# cloud-init guests, one module instance per VM, grouped by role in vm_<role>.tofu
locals {

  # LAN first, internal second: ip_config order is the guest's NIC order
  vm_network_interfaces = {
    for k, v in var.vms : k => [
      { bridge = var.network_lan.bridge, address = "${cidrhost(var.network_lan.cidr, v.vm_id)}/${local.lan_prefix}", gateway = var.network_lan.gateway },
      { bridge = var.network_internal.bridge, address = "${cidrhost(var.network_internal.cidr, v.vm_id)}/${local.internal_prefix}", gateway = var.network_internal.gateway },
    ]
  }

  vm_ssh_public_keys = {
    for k, v in var.vms : k => [for p in v.ssh_public_key_paths : trimspace(file("${var.REPO_ROOT}/${p}"))]
  }
}











# Any other VM
module "generic_vms" {
  source   = "./modules/cloudinit-vm"
  for_each = { for k, v in var.vms : k => v if v.role == "" }

  depends_on = [
    proxmox_network_linux_bridge.network_internal,
    proxmox_network_linux_bridge.network_lan,
    proxmox_virtual_environment_pool.k3s,
  ]

  name               = each.key
  vm                 = each.value
  pool_id            = ""
  network_interfaces = local.vm_network_interfaces[each.key]
  datastores         = var.proxmox_datastores
  image_file_id      = proxmox_download_file.ubuntu_resolute_cloudinit.id
  username           = var.vm_username
  ssh_public_keys    = local.vm_ssh_public_keys[each.key]
}







# k3s cluster VMs
module "k3s" {
  source   = "./modules/cloudinit-vm"
  for_each = { for k, v in var.vms : k => v if v.role == "k3s" }

  depends_on = [
    proxmox_network_linux_bridge.network_internal,
    proxmox_network_linux_bridge.network_lan,
    proxmox_virtual_environment_pool.k3s,
  ]

  name               = each.key
  vm                 = each.value
  pool_id            = var.proxmox_pool_name
  network_interfaces = local.vm_network_interfaces[each.key]
  datastores         = var.proxmox_datastores
  image_file_id      = proxmox_download_file.ubuntu_resolute_cloudinit.id
  username           = var.vm_username
  ssh_public_keys    = local.vm_ssh_public_keys[each.key]
}






# Home Assistant OS
resource "proxmox_virtual_environment_vm" "haos" {
  for_each = { for k, v in var.vms : k => v if v.role == "haos" }

  depends_on = [
    proxmox_network_linux_bridge.network_internal,
    proxmox_network_linux_bridge.network_lan,
  ]

  vm_id       = each.value.vm_id
  name        = each.key
  description = "Managed by OpenTofu"
  node_name   = each.value.node_name

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
    cores = each.value.cores
    type  = "qemu64"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = each.value.datastore
    interface    = "scsi0"
    size         = each.value.disk_size
    cache        = "writeback"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
  }

  network_device {
    bridge      = var.network_lan.bridge
    mac_address = each.value.mac_lan
  }

  network_device {
    bridge      = var.network_internal.bridge
    mac_address = each.value.mac_internal
  }

  # Zigbee/Z-Wave stick
  usb {
    host = each.value.usb_host
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
  }
}






# Tailscale exit node
module "tailscale" {
  source   = "./modules/cloudinit-vm"
  for_each = { for k, v in var.vms : k => v if v.role == "tailscale" }

  depends_on = [
    proxmox_network_linux_bridge.network_internal,
    proxmox_network_linux_bridge.network_lan,
    proxmox_virtual_environment_pool.k3s,
  ]

  name               = each.key
  vm                 = each.value
  pool_id            = ""
  network_interfaces = local.vm_network_interfaces[each.key]
  datastores         = var.proxmox_datastores
  image_file_id      = proxmox_download_file.ubuntu_resolute_cloudinit.id
  username           = var.vm_username
  ssh_public_keys    = local.vm_ssh_public_keys[each.key]
}
