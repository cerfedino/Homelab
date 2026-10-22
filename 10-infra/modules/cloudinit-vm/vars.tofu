variable "name" {
  type = string
}

variable "vm" {
  type = object({
    vm_id      = number
    node_name  = string
    cores      = number
    memory     = number
    ballooning = bool
    disk_size  = number
  })
}

variable "pool_id" {
  type = string
}

# LAN first, internal second: ip_config order is the guest's NIC order
variable "network_interfaces" {
  type = list(object({
    bridge  = string
    address = string
    gateway = optional(string)
  }))
}

variable "datastores" {
  type = object({
    disk    = string
    init    = string
    snippet = string
  })
}

variable "image_file_id" {
  type = string
}

variable "username" {
  type = string
}

variable "ssh_public_keys" {
  type = list(string)
}
