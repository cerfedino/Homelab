resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = var.datastores.snippet
  node_name    = var.vm.node_name

  source_raw {
    file_name = "${var.name}-user-data.yaml"
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname        = var.name
      packages        = ["qemu-guest-agent"]
      runcmd          = ["systemctl enable --now qemu-guest-agent"]
      username        = var.username
      ssh_public_keys = var.ssh_public_keys
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  vm_id       = var.vm.vm_id
  name        = var.name
  description = "Managed by OpenTofu"
  node_name   = var.vm.node_name

  pool_id = var.pool_id

  stop_on_destroy = true

  agent {
    enabled = true
  }

  tags = ["tofu"]

  cpu {
    cores = var.vm.cores
    type  = "host"
  }

  memory {
    dedicated = var.vm.memory
    floating  = var.vm.ballooning ? var.vm.memory : 0
  }

  disk {
    import_from  = var.image_file_id
    datastore_id = var.datastores.disk
    interface    = "scsi0"
    size         = var.vm.disk_size
  }

  initialization {
    datastore_id      = var.datastores.init
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    dynamic "ip_config" {
      for_each = var.network_interfaces
      content {
        ipv4 {
          address = ip_config.value.address
          gateway = ip_config.value.gateway
        }
      }
    }

    dns {
      servers = ["1.1.1.1"]
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

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      initialization[0].dns,
    ]
  }
}
