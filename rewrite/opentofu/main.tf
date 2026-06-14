terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox.endpoint
  api_token = var.proxmox.api_token
  insecure  = true

  ssh {
    agent    = true
    username = "root"
  }
}

# resource "proxmox_network_linux_bridge" "vmbr1" {
#   node_name = "pve1"
#   name      = "vmbr1"

#   address = "10.10.10.202/24"
#   comment = "proxmox_internal"
#   autostart = true
# }


# Shared Ubuntu cloud image — downloaded once, reused by every VM.
resource "proxmox_download_file" "ubuntu_resolute_cloudinit" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve1"

  url       = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
  file_name = "resolute-server-cloudimg-amd64.qcow2"

  checksum           = "dced94c031cc1f23dee14419a3723a5b110df9938de0ac31913a2bfd07c755b4"
  checksum_algorithm = "sha256"
}

module "vm" {
  source   = "./modules/vm"
  for_each = var.nodes

  name      = coalesce(each.value.display_name, each.key)
  vm_id     = each.value.vm_id
  node_name = each.value.node_name
  cores     = each.value.cores
  memory    = each.value.memory
  disk_size = each.value.disk_size

  dns_servers        = each.value.dns_servers
  network_interfaces = each.value.network_interfaces

  runcmd = each.value.runcmd
  packages = each.value.packages

  image_file_id     = proxmox_download_file.ubuntu_resolute_cloudinit.id
  disk_datastore    = "zfs"
  init_datastore    = "zfs"
  snippet_datastore = "local"

  username = each.value.username
  ssh_public_key    = trimspace(file("${path.module}/keys/nodes.pub"))
}

