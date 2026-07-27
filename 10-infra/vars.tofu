variable "proxmox" {
  type = object({
    endpoint_lan  = string
    endpoint_internal = string

    # User with following Role permissions on /:
    # VM.Config.HWType, Pool.Allocate, Sys.Modify, VM.Config.CDROM, VM.Config.Cloudinit, VM.Clone, VM.Config.Network, Sys.Console, VM.Config.Memory, VM.PowerMgmt, VM.Config.CPU, VM.Config.Disk, VM.Migrate, VM.Allocate, User.Modify, Sys.Audit, VM.Config.Options, Datastore.Allocate, VM.Audit, SDN.Use, VM.Monitor, Datastore.AllocateTemplate, Datastore.Audit, Realm.AllocateUser, Datastore.AllocateSpace, Pool.Audit
    api_token = string # format: USER@REALM!TOKENID=SECRET
    # Path relative to REPO_ROOT
    root_privkey_path = string
  })
  sensitive = true
}

# Root of the cloned repository. Variable set by the devbox environment
variable "REPO_ROOT" {
    type = string
}

variable "proxmox_cluster_name" {
  type      = string
}

variable "proxmox_node_name" {
  type      = string
}

variable "proxmox_storage_name" {
  type      = string
}

variable "proxmox_pool_name" {
  type      = string
}

variable "proxmox_datastores" {
  type = object({
    disk    = string # VM root disks
    init    = string # cloud-init drives
    snippet = string # cloud-init user-data snippets
  })
}

# Operator account cloud-init creates on every VM
variable "vm_username" {
  type      = string
}

variable "CSI_user_password" {
  type      = string
  sensitive = true
}

variable "network_lan" {
  type = object({
    cidr    = string # e.g. "192.168.1.0/24"
    bridge  = string # e.g. "vmbr0"
    gateway = string
    bridge_ports = list(string)
  })

  validation {
    condition     = can(cidrhost(var.network_lan.cidr, 0))
    error_message = "network_lan.cidr must be valid CIDR notation, e.g. 192.168.1.0/24."
  }

  validation {
    condition     = can(regex("^vmbr[0-9]+$", var.network_lan.bridge))
    error_message = "network_lan.bridge must be a Proxmox bridge name like vmbr0."
  }

  validation {
    condition     = can(cidrhost("${var.network_lan.gateway}/32", 0))
    error_message = "network_lan.gateway must be a valid IPv4 address."
  }
}

variable "network_internal" {
  type = object({
    cidr    = string # e.g. "10.10.10.0/24"
    bridge  = string # e.g. "vmbr1"
    gateway = optional(string)
  })

  validation {
    condition     = can(cidrhost(var.network_internal.cidr, 0))
    error_message = "network_internal.cidr must be valid CIDR notation, e.g. 10.10.10.0/24."
  }

  validation {
    condition     = can(regex("^vmbr[0-9]+$", var.network_internal.bridge))
    error_message = "network_internal.bridge must be a Proxmox bridge name like vmbr1."
  }

  validation {
    condition     = var.network_internal.gateway == null || can(cidrhost("${var.network_internal.gateway}/32", 0))
    error_message = "network_internal.gateway, if set, must be a valid IPv4 address."
  }
}

variable "domain" {
  type = string # e.g. "example.com"
}

variable "domain_lan" {
  type = string # e.g. "lan.example.com"
}

variable "dnsmasq_upstream_servers" {
  type = list(string)

  validation {
    condition     = length(var.dnsmasq_upstream_servers) > 0
    error_message = "dnsmasq_upstream_servers must contain at least one DNS server."
  }

  validation {
    condition = alltrue([
      for server in var.dnsmasq_upstream_servers :
      can(cidrhost("${server}/32", 0)) || can(cidrhost("${server}/128", 0))
    ])
    error_message = "dnsmasq_upstream_servers entries must be IP addresses."
  }
}

variable "dnsmasq_address_entries" {
  type = list(object({
    domain  = string
    address = string
  }))

  validation {
    condition = alltrue([
      for entry in var.dnsmasq_address_entries :
      length(trimspace(entry.domain)) > 0 && !strcontains(entry.domain, "/")
    ])
    error_message = "dnsmasq_address_entries domains must be non-empty and cannot contain '/'."
  }

  validation {
    condition = alltrue([
      for entry in var.dnsmasq_address_entries :
      can(cidrhost("${entry.address}/32", 0)) || can(cidrhost("${entry.address}/128", 0))
    ])
    error_message = "dnsmasq_address_entries addresses must be IP addresses."
  }
}

# kube-vip control-plane VIP. The VIP floats between k3s servers for HA
variable "kube_vip_cp_address" {
  type = string

  validation {
    condition     = can(cidrhost("${var.kube_vip_cp_address}/32", 0))
    error_message = "kube_vip_cp_address must be a valid IPv4 address."
  }
}

# kube-vip LoadBalancer-service VIP (LAN entrypoint, e.g. Traefik)
variable "kube_vip_svc_address" {
  type = string

  validation {
    condition     = can(cidrhost("${var.kube_vip_svc_address}/32", 0))
    error_message = "kube_vip_svc_address must be a valid IPv4 address."
  }

  validation {
    condition     = var.kube_vip_svc_address != var.kube_vip_cp_address
    error_message = "kube_vip_svc_address must differ from kube_vip_cp_address"
  }
}

# VMs to create
variable "vm_k3s" {
  type = map(object({
    vm_id        = number
    display_name = string
    node_name    = string
    cores       = number
    memory      = number
    ballooning  = optional(bool, false)
    disk_size   = number
    # Paths relative to REPO_ROOT
    ssh_public_key_paths = list(string)
    ssh_private_key_paths = list(string)
  }))

  validation {
    condition     = length([for k, v in var.vm_k3s : 1 if length(v.ssh_public_key_paths) < 1]) == 0
    error_message = "At least one SSH pubkey for each VM such that Ansible can connect to the VM"
  }

  validation {
    condition     = length([for k, v in var.vm_k3s : 1 if length(v.ssh_private_key_paths) < 1]) == 0
    error_message = "At least one SSH pubkey for each VM such that Ansible can connect to the VM"
  }

  validation {
    condition     = length([for k, v in var.vm_k3s : 1 if v.vm_id <=0 || v.vm_id >= 255 ]) == 0
    error_message = "VM ID has to be in range [1, 254]"
  }

  validation {
    condition     = length(distinct([for k, v in var.vm_k3s : v.vm_id])) == length(var.vm_k3s)
    error_message = "vm_k3s VM IDs must be unique"
  }
}

variable "vm_tailscale" {
  type = object({
    vm_id        = number
    display_name = string
    node_name    = string
    cores       = number
    memory      = number
    ballooning  = optional(bool, false)
    disk_size   = number
    # Paths relative to REPO_ROOT
    ssh_public_key_paths = list(string)
    ssh_private_key_paths = list(string)
  })

  validation {
    condition     = length(var.vm_tailscale.ssh_public_key_paths) > 0
    error_message = "At least one SSH pubkey for each VM such that Ansible can connect to the VM"
  }

  validation {
    condition     = length(var.vm_tailscale.ssh_private_key_paths) > 0
    error_message = "At least one SSH private key for each VM such that Ansible can connect to the VM"
  }

  validation {
    condition     = var.vm_tailscale.vm_id > 0 && var.vm_tailscale.vm_id < 255
    error_message = "VM ID has to be in range [1, 254]"
  }

  validation {
    condition     = !contains([for k, v in var.vm_k3s : v.vm_id], var.vm_tailscale.vm_id)
    error_message = "vm_tailscale.vm_id collides with a vm_k3s VM ID"
  }
}
