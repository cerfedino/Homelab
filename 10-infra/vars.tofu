variable "proxmox" {
  type = object({
    endpoint_lan  = string
    endpoint_internal = string
    insecure          = bool

    # User with following Role permissions on /:
    # Datastore.Audit, Sys.Audit, VM.Migrate, VM.Audit, VM.PowerMgmt, SDN.Use, Realm.AllocateUser, VM.Config.Network, Pool.Allocate, Datastore.Allocate, VM.GuestAgent.Audit, User.Modify, VM.Config.Disk, VM.Config.HWType, Sys.Console, VM.Allocate, VM.Config.CPU, VM.Config.Cloudinit, Datastore.AllocateSpace, VM.Config.Options, VM.Clone, Datastore.AllocateTemplate, VM.Config.Memory, Pool.Audit, VM.Config.CDROM, Sys.Modify, Group.Allocate, Mapping.Audit, Mapping.Modify, Mapping.Use, Permissions.Modify, Realm.Allocate, SDN.Allocate, SDN.Audit, Sys.AccessNetwork, Sys.Incoming, Sys.PowerMgmt, Sys.Syslog, VM.Backup, VM.Console, VM.GuestAgent.FileRead, VM.GuestAgent.FileSystemMgmt, VM.GuestAgent.FileWrite, VM.GuestAgent.Unrestricted, VM.Replicate, VM.Snapshot, VM.Snapshot.Rollback
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

# data of the PVE ACME DNS plugin
variable "acme_cloudflare" {
  type = object({
    CF_Account_ID = string
    CF_Token      = string
  })
  sensitive = true
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

# kube-vip LoadBalancer-service VIP for the user-facing DNS server (Pi-hole)
variable "pihole_svc_address" {
  type = string

  validation {
    condition     = can(cidrhost("${var.pihole_svc_address}/32", 0))
    error_message = "pihole_svc_address must be a valid IPv4 address."
  }

  validation {
    condition     = var.pihole_svc_address != var.kube_vip_cp_address && var.pihole_svc_address != var.kube_vip_svc_address
    error_message = "pihole_svc_address must differ from kube_vip_cp_address and kube_vip_svc_address"
  }
}

# Hetzner Object Storage S3 credentials (created with GUI)
variable "hetzner_s3" {
  type = object({
    endpoint   = string # e.g. "fsn1.your-objectstorage.com"
    region     = string # e.g. "fsn1"
    access_key = string
    secret_key = string
  })
  sensitive = true

  validation {
    condition     = !strcontains(var.hetzner_s3.endpoint, "://")
    error_message = "hetzner_s3.endpoint must be a bare hostname without scheme."
  }
}

variable "backup_bucket" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.backup_bucket))
    error_message = "backup_bucket must be a valid S3 bucket name."
  }
}

variable "backup_restic_password" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.backup_restic_password) >= 16
    error_message = "backup_restic_password must be at least 16 characters."
  }
}

# VMs to create. 
# 'role' must be one of k3s, tailscale if the VM fits a specific purpose, or blank if it doesn't.
variable "vms" {
  type = map(object({
    role       = optional(string, "") # k3s | tailscale | haos | blank
    vm_id      = number
    node_name  = string
    cores      = number
    memory     = number
    ballooning = optional(bool, false)
    disk_size  = number
    # cloud-init roles. Paths relative to REPO_ROOT
    ssh_public_key_paths  = optional(list(string), [])
    ssh_private_key_paths = optional(list(string), [])
    # haos
    datastore    = optional(string)
    mac_lan      = optional(string)
    mac_internal = optional(string)
    usb_host     = optional(string)
  }))

  validation {
    condition     = alltrue([for _, v in var.vms : contains(["k3s", "tailscale", "haos", ""], v.role)])
    error_message = "vms role must be one of k3s, tailscale, haos or blank"
  }

  validation {
    condition     = alltrue([for _, v in var.vms : v.vm_id > 0 && v.vm_id < 255])
    error_message = "VM ID has to be in range [1, 254]"
  }

  validation {
    condition     = length(distinct([for _, v in var.vms : v.vm_id])) == length(var.vms)
    error_message = "VM IDs must be unique"
  }

  validation {
    condition     = alltrue([for _, v in var.vms : length(v.ssh_public_key_paths) > 0 && length(v.ssh_private_key_paths) > 0 if v.role != "haos"])
    error_message = "cloud-init VMs need at least one SSH public and private key such that Ansible can connect"
  }

  validation {
    condition     = alltrue([for _, v in var.vms : v.datastore != null && v.mac_lan != null && v.mac_internal != null && v.usb_host != null if v.role == "haos"])
    error_message = "haos VMs need datastore, mac_lan, mac_internal and usb_host"
  }
}

# k3s pod and service networks (its cluster-cidr and service-cidr)
variable "k3s_cluster_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.k3s_cluster_cidr, 0))
    error_message = "k3s_cluster_cidr must be an IPv4 CIDR."
  }
}

variable "k3s_service_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.k3s_service_cidr, 0))
    error_message = "k3s_service_cidr must be an IPv4 CIDR."
  }
}
