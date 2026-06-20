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
    private_key = core::file("/home/cerfe/.ssh/keys/NUC/pve1/pve1_root")
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

  checksum           = "0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670"
  checksum_algorithm = "sha256"
}

module "vm_k8s" {
  source   = "./modules/vm"
  for_each = var.vm_k8s

  name      = each.value.display_name
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
  ssh_public_key_paths    = each.value.ssh_public_key_paths
  ssh_private_key_paths    = each.value.ssh_private_key_paths
}


module "vm_tailscale" {
  source = "./modules/vm"

  name      = var.vm_tailscale.display_name
  vm_id     = var.vm_tailscale.vm_id
  node_name = var.vm_tailscale.node_name
  cores     = var.vm_tailscale.cores
  memory    = var.vm_tailscale.memory
  disk_size = var.vm_tailscale.disk_size

  dns_servers        = var.vm_tailscale.dns_servers
  network_interfaces = var.vm_tailscale.network_interfaces

  runcmd = var.vm_tailscale.runcmd
  packages = var.vm_tailscale.packages

  image_file_id     = proxmox_download_file.ubuntu_resolute_cloudinit.id
  disk_datastore    = "zfs"
  init_datastore    = "zfs"
  snippet_datastore = "local"

  username = var.vm_tailscale.username
  ssh_public_key_paths    = var.vm_tailscale.ssh_public_key_paths
  ssh_private_key_paths    = var.vm_tailscale.ssh_private_key_paths
}