terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "${var.name}-user-data.yaml"
    data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      hostname       = var.name
      packages       = var.packages
      runcmd = var.runcmd
      username       = var.username
      ssh_public_keys = [for pubkey in var.ssh_public_key_paths : trimspace(file(pubkey))]
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  vm_id       = var.vm_id
  name        = var.name
  description = "Managed by OpenTofu"
  node_name   = var.node_name

  pool_id = var.pool

  stop_on_destroy = true

  agent {
    enabled = true
  }

  tags = [ "tofu" ]

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
    floating  = var.ballooning ? var.memory : 0
  }

  disk {
    import_from  = var.image_file_id
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.disk_size
  }

  initialization {
    datastore_id      = var.init_datastore
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    dynamic "ip_config" {
      for_each = var.network_interfaces
      content {
        ipv4 {
          address = ip_config.value.address
          gateway = try(ip_config.value.gateway, null)
        }
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }
  }

  dynamic "network_device" {
    for_each = var.network_interfaces
    content {
      bridge = network_device.value.bridge
    }
  }

  operating_system {
    type = "l26"
  }
}
