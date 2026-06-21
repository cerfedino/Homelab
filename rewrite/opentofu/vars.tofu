variable "proxmox" {
  type = object({
    endpoint  = string
    api_token = string # format: USER@REALM!TOKENID=SECRET
    root_privkey_path = string
  })
  sensitive = true
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
    username = string
    network_interfaces = list(object({
      bridge  = string
      address = string
      gateway = optional(string)
    }))
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
    username = string
    network_interfaces = list(object({
      bridge  = string
      address = string
      gateway = optional(string)
    }))
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
}

