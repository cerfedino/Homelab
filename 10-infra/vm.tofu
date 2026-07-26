# Every VM in one map: the k3s nodes carry the pool, the tailscale gateway does not.
locals {
  vms = merge(
    { for k, v in var.vm_k3s : k => merge(v, { pool = var.proxmox_pool_name }) },
    { tailscale = merge(var.vm_tailscale, { pool = "" }) },
  )

  # LAN first, internal second: ip_config order is the guest's NIC order
  vm_network_interfaces = {
    for k, v in local.vms : k => [
      { bridge = var.network_lan.bridge, address = "${cidrhost(var.network_lan.cidr, v.vm_id)}/${local.lan_prefix}", gateway = var.network_lan.gateway },
      { bridge = var.network_internal.bridge, address = "${cidrhost(var.network_internal.cidr, v.vm_id)}/${local.internal_prefix}", gateway = var.network_internal.gateway },
    ]
  }
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = local.vms

  content_type = "snippets"
  datastore_id = var.proxmox_datastores.snippet
  node_name    = each.value.node_name

  source_raw {
    file_name = "${each.value.display_name}-user-data.yaml"
    data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      hostname        = each.value.display_name
      packages        = ["qemu-guest-agent"]
      runcmd          = ["systemctl enable --now qemu-guest-agent"]
      username        = var.vm_username
      ssh_public_keys = [for p in each.value.ssh_public_key_paths : trimspace(file("${var.REPO_ROOT}/${p}"))]
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  for_each = local.vms

  depends_on = [
    proxmox_network_linux_bridge.network_internal,
    proxmox_network_linux_bridge.network_lan,
    proxmox_virtual_environment_pool.k3s,
  ]

  vm_id       = each.value.vm_id
  name        = each.value.display_name
  description = "Managed by OpenTofu"
  node_name   = each.value.node_name

  pool_id = each.value.pool

  stop_on_destroy = true

  agent {
    enabled = true
  }

  tags = ["tofu"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
    floating  = each.value.ballooning ? each.value.memory : 0
  }

  disk {
    import_from  = proxmox_download_file.ubuntu_resolute_cloudinit.id
    datastore_id = var.proxmox_datastores.disk
    interface    = "scsi0"
    size         = each.value.disk_size
  }

  initialization {
    datastore_id      = var.proxmox_datastores.init
    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id

    dynamic "ip_config" {
      for_each = local.vm_network_interfaces[each.key]
      content {
        ipv4 {
          address = ip_config.value.address
          gateway = try(ip_config.value.gateway, null)
        }
      }
    }

    dynamic "dns" {
      for_each = length(each.value.dns_servers) > 0 ? [1] : []
      content {
        servers = each.value.dns_servers
      }
    }
  }

  dynamic "network_device" {
    for_each = local.vm_network_interfaces[each.key]
    content {
      bridge = network_device.value.bridge
    }
  }

  operating_system {
    type = "l26"
  }
}
