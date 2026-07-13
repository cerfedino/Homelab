variable "vm_id" {
  type = number
}

variable "name" {
  type = string
}

variable "node_name" {
  type = string
}

variable "pool" {
  type = string
  default = ""
}

variable "cores" {
  type    = number
}

variable "memory" {
  type    = number
}

variable "image_file_id" {
  type = string
}

variable "disk_size" {
  type    = number
}

variable "disk_datastore" {
  type = string
}

variable "init_datastore" {
  type = string
}

variable "snippet_datastore" {
  type = string
}

variable "username" {
  type = string
}

variable "ssh_public_key_paths" {
  type = list(string)
}

variable "ssh_private_key_paths" {
  type = list(string)
}

variable "packages" {
  type    = list(string)
}

variable "runcmd" {
    type = list(string)
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "network_interfaces" {
  type = list(object({
    bridge  = string
    address = string # CIDR (e.g. "192.168.1.220/24") or "dhcp"
    gateway = optional(string)
  }))
}
