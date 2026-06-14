variable "proxmox" {
  type = object({
    endpoint  = string
    api_token = string # format: USER@REALM!TOKENID=SECRET
  })
  sensitive = true
}

# VMs to create
variable "nodes" {
  type = map(object({
    vm_id        = number
    display_name = optional(string)
    node_name    = optional(string, "pve1")
    cores       = optional(number, 2)
    memory      = optional(number, 2048)
    disk_size   = optional(number, 20)
    dns_servers = optional(list(string), [])
    packages = optional(list(string), [])
    runcmd =  optional(list(string), [])
    username = optional(string, "cerfe")
    network_interfaces = list(object({
      bridge  = string
      address = string
      gateway = optional(string)
    }))
  }))
}
