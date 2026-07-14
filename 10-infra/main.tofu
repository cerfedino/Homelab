terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.110"
    }
    http = {
      source = "hashicorp/http"
      version = "3.6.0"
    }
  }

  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    method "unencrypted" "migrate" {}
    
    state {
      method = method.aes_gcm.state
      fallback { method = method.unencrypted.migrate }
    }
    
    # state {
    #   method = method.unencrypted.migrate
    #   fallback { method = method.aes_gcm.state }
    # }
    plan {
      method = method.aes_gcm.state
    }
  }
}
provider proxmox {

  endpoint  = var.proxmox.endpoint_lan
  api_token = var.proxmox.api_token
  insecure  = true

  ssh {
    agent    = true
    username = "root"
    private_key = core::file("${var.REPO_ROOT}/${var.proxmox.root_privkey_path}")
  }
}

resource "proxmox_virtual_environment_role" "CSI" {
  role_id = "CSI"

  privileges = [
    "VM.Audit","VM.Allocate","VM.Clone","VM.Config.CPU","VM.Config.Disk","VM.Config.HWType","VM.Config.Memory","VM.Config.Options","VM.Migrate","VM.PowerMgmt","Datastore.Allocate","Datastore.AllocateSpace","Datastore.Audit"
  ]
}
resource "proxmox_virtual_environment_user" "CSI" {
  comment  = "Managed by OpenTofu"
  password =var.CSI_user_password
  user_id  = "CSI@pve"
}

resource "proxmox_acl" "CSI" {
  user_id = proxmox_virtual_environment_user.CSI.user_id
  role_id = proxmox_virtual_environment_role.CSI.role_id

  path      = "/pool/${local.k3s_pool}"
  propagate = true
}

resource "proxmox_user_token" "CSI" {
  comment    = "Kubernetes CSI - Managed by OpenTofu"
  token_name = "CSI"
  user_id    = proxmox_virtual_environment_user.CSI.user_id
}


data "http" "ubuntu_images_checksums" {
  url    = "https://cloud-images.ubuntu.com/resolute/${local.ubuntu_image_release}/SHA256SUMS"
  method = "GET"
}

resource "proxmox_network_linux_bridge" "network_lan" {
  node_name = var.proxmox_node_name
  name      = var.network_lan.bridge

  address = var.network_lan.cidr
  gateway = var.network_lan.gateway
  comment = "LAN"
  autostart = true
  ports = var.network_lan.bridge_ports

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_network_linux_bridge" "network_internal" {
  node_name = var.proxmox_node_name
  name      = var.network_internal.bridge

  address = var.network_internal.cidr
  comment = "proxmox_internal"
  autostart = true

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  ubuntu_image_release  = "20260627"
  ubuntu_image_filename = "resolute-server-cloudimg-amd64"

  lan_prefix      = split("/", var.network_lan.cidr)[1]
  internal_prefix = split("/", var.network_internal.cidr)[1]

  k3s_pool = "k3s"

  # Every VM's LAN IP. Used to guarantee the kube-vip VIP doesn't collide with a VM.
  vm_lan_ips = concat(
    [for _, v in var.vm_k3s : cidrhost(var.network_lan.cidr, v.vm_id)],
    [cidrhost(var.network_lan.cidr, var.vm_tailscale.vm_id)],
  )
}
resource "proxmox_download_file" "ubuntu_resolute_cloudinit" {
  content_type = "import"
  datastore_id = "local"
  node_name = var.proxmox_node_name
  depends_on = [proxmox_network_linux_bridge.network_lan]

  url       = "https://cloud-images.ubuntu.com/resolute/${local.ubuntu_image_release}/${local.ubuntu_image_filename}.img"
  file_name = "${local.ubuntu_image_filename}.qcow2"

  checksum           = regex("(?m)^([a-f0-9]{64}) \\*${local.ubuntu_image_filename}.img$",data.http.ubuntu_images_checksums.response_body)[0]
  checksum_algorithm = "sha256"
}

resource "proxmox_virtual_environment_pool" "k3s" {
  comment = "Managed by OpenTofu"
  pool_id = local.k3s_pool
}

module "vm_k3s" {
  source   = "./modules/vm"
  for_each = var.vm_k3s
  depends_on = [ proxmox_network_linux_bridge.network_internal, proxmox_network_linux_bridge.network_lan, proxmox_virtual_environment_pool.k3s ]

  name      = each.value.display_name
  vm_id     = each.value.vm_id
  node_name = each.value.node_name
  cores     = each.value.cores
  memory    = each.value.memory
  disk_size = each.value.disk_size

  pool = local.k3s_pool


  dns_servers        = each.value.dns_servers
  network_interfaces = [
    { bridge = var.network_lan.bridge,      address = "${cidrhost(var.network_lan.cidr, each.value.vm_id)}/${local.lan_prefix}",           gateway = var.network_lan.gateway },
    { bridge = var.network_internal.bridge, address = "${cidrhost(var.network_internal.cidr, each.value.vm_id)}/${local.internal_prefix}", gateway = var.network_internal.gateway },
  ]
  packages = ["qemu-guest-agent"]
  runcmd =  ["systemctl enable --now qemu-guest-agent"]

  image_file_id     = proxmox_download_file.ubuntu_resolute_cloudinit.id
  disk_datastore    = "local-zfs"
  init_datastore    = "zfs"
  snippet_datastore = "local"

  username = "cerfe"
  ssh_public_key_paths    = [for i, v in each.value.ssh_public_key_paths : "${var.REPO_ROOT}/${v}"]
  ssh_private_key_paths    = [for i, v in each.value.ssh_private_key_paths : "${var.REPO_ROOT}/${v}"]
}


module "vm_tailscale" {
  source = "./modules/vm"
  depends_on = [ proxmox_network_linux_bridge.network_internal, proxmox_network_linux_bridge.network_lan ]

  name      = var.vm_tailscale.display_name
  vm_id     = var.vm_tailscale.vm_id
  node_name = var.vm_tailscale.node_name
  cores     = var.vm_tailscale.cores
  memory    = var.vm_tailscale.memory
  disk_size = var.vm_tailscale.disk_size

  dns_servers        = var.vm_tailscale.dns_servers
  network_interfaces = [
    { bridge = var.network_lan.bridge,      address = "${cidrhost(var.network_lan.cidr, var.vm_tailscale.vm_id)}/${local.lan_prefix}",           gateway = var.network_lan.gateway },
    { bridge = var.network_internal.bridge, address = "${cidrhost(var.network_internal.cidr, var.vm_tailscale.vm_id)}/${local.internal_prefix}", gateway = var.network_internal.gateway },
  ]

  packages = ["qemu-guest-agent"]
  runcmd =  ["systemctl enable --now qemu-guest-agent"]

  image_file_id     = proxmox_download_file.ubuntu_resolute_cloudinit.id
  disk_datastore    = "local-zfs"
  init_datastore    = "zfs"
  snippet_datastore = "local"

  username = "cerfe"
  ssh_public_key_paths    = [for i, v in var.vm_tailscale.ssh_public_key_paths : "${var.REPO_ROOT}/${v}"]
  ssh_private_key_paths    = [for i, v in var.vm_tailscale.ssh_private_key_paths : "${var.REPO_ROOT}/${v}"]
}