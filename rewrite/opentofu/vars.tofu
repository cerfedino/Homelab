variable "proxmox" {
  type = object({
    endpoint  = string
    api_token = string # format: USER@REALM!TOKENID=SECRET
    root_privkey_path = string
  })
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

# VMs to create
variable "vm_k8s" {
  type = map(object({
    vm_id        = number
    display_name = string
    node_name    = string
    cores       = number
    pool = optional(string)
    memory      = number
    disk_size   = number
    dns_servers = list(string)
    packages = optional(list(string), [])
    runcmd =  optional(list(string), [])
    ssh_public_key_paths = list(string)
    ssh_private_key_paths = list(string)
  }))

  validation {
    condition     = length([for k, v in var.vm_k8s : 1 if length(v.ssh_public_key_paths) < 1]) == 0
    error_message = "At least one SSH pubkey for each VM such that Ansible can connect to the VM"
  }

  validation {
    condition     = length([for k, v in var.vm_k8s : 1 if length(v.ssh_private_key_paths) < 1]) == 0
    error_message = "At least one SSH pubkey for each VM such that Ansible can connect to the VM"
  }

  validation {
    condition     = length([for k, v in var.vm_k8s : 1 if v.vm_id <=0 || v.vm_id >= 255 ]) == 0
    error_message = "VM ID has to be in range [1, 254]"
  }
}

variable "vm_tailscale" {
  type = object({
    vm_id        = number
    display_name = string
    node_name    = string
    cores       = number
    pool = optional(string)
    memory      = number
    disk_size   = number
    dns_servers = list(string)
    packages = optional(list(string), [])
    runcmd =  optional(list(string), [])
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
}

