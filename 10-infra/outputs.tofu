
locals {
  machines = merge(
    { for k, v in var.vms : k => {
        fqdn_internal = "${k}.internal.${var.domain}"
        fqdn_lan      = "${k}.lan.${var.domain}"
        ip_internal   = cidrhost(var.network_internal.cidr, v.vm_id)
        ip_lan        = cidrhost(var.network_lan.cidr, v.vm_id)
    } },
    # the PVE hosts: their addresses are the host parts of the network cidrs
    { for n in toset([for _, v in var.vms : v.node_name]) : n => {
        fqdn_internal = "${n}.internal.${var.domain}"
        fqdn_lan      = "${n}.lan.${var.domain}"
        ip_internal   = split("/", var.network_internal.cidr)[0]
        ip_lan        = split("/", var.network_lan.cidr)[0]
    } },
  )
  machine_dns_entries = flatten([for name, m in local.machines : [
    { domain = m.fqdn_internal, address = m.ip_internal },
    { domain = m.fqdn_lan,      address = m.ip_lan },
  ]])
  dnsmasq_all_entries = concat(local.machine_dns_entries, var.dnsmasq_address_entries)
}

# every host Ansible and ssh can log into: the cloud-init guests and the PVE hosts
locals {
  ansible_hosts = merge(
    { for k, v in var.vms : k => {
        ansible_host                 = local.machines[k].ip_lan
        ansible_user                 = var.vm_username
        ansible_ssh_private_key_file = "${var.REPO_ROOT}/${v.ssh_private_key_paths[0]}"
        vm_id                        = v.vm_id
        proxmox_node_name            = v.node_name
        ip_lan                       = local.machines[k].ip_lan
        ip_internal                  = local.machines[k].ip_internal
    } if v.role != "haos" },
    { for n in toset([for _, v in var.vms : v.node_name]) : n => {
        ansible_host                 = local.machines[n].ip_lan
        ansible_user                 = "root"
        ansible_ssh_private_key_file = "${var.REPO_ROOT}/${var.proxmox.root_privkey_path}"
        ansible_ssh_common_args      = "-o IdentitiesOnly=yes"
        ip_lan                       = local.machines[n].ip_lan
        ip_internal                  = local.machines[n].ip_internal
    } },
  )
}

output "ansible_yaml_inventory" {
  sensitive = true
  value = yamlencode({
    all = {
      hosts = local.ansible_hosts
      children = {
        k3s_cluster = {
          children = {
            server = {
              hosts = { for k, v in var.vms : k => null if v.role == "k3s" }
            }
          }
          vars = {
            kube_vip_cp_address  = var.kube_vip_cp_address
            kube_vip_svc_address = var.kube_vip_svc_address
            k3s_server_lan_ips   = [for _, v in var.vms : cidrhost(var.network_lan.cidr, v.vm_id) if v.role == "k3s"]
            proxmox_cluster_name = var.proxmox_cluster_name
            k3s_cluster_cidr     = var.k3s_cluster_cidr
            k3s_service_cidr     = var.k3s_service_cidr
          }
        }
        tailscale_gw = {
          hosts = { for k, v in var.vms : k => null if v.role == "tailscale" }
        }
        generic_vms = {
          hosts = { for k, v in var.vms : k => null if v.role == "" }
        }
        pve = {
          hosts = { for n in toset([for _, v in var.vms : v.node_name]) : n => null }
        }
      }
      vars = {
        dnsmasq_upstream_servers = var.dnsmasq_upstream_servers
        dnsmasq_address_entries  = local.dnsmasq_all_entries
        network_lan = {
          cidr    = "${cidrhost(var.network_lan.cidr, 0)}/${split("/", var.network_lan.cidr)[1]}"
          bridge  = var.network_lan.bridge
          gateway = var.network_lan.gateway
        }
        network_internal = {
          cidr    = "${cidrhost(var.network_internal.cidr, 0)}/${split("/", var.network_internal.cidr)[1]}"
          bridge  = var.network_internal.bridge
          gateway = var.network_internal.gateway
        }
      }
    }
  })


  # The VIPs must live on the LAN subnet (so ARP works) ...
  precondition {
    condition     = cidrhost("${var.kube_vip_cp_address}/${local.lan_prefix}", 0) == cidrhost(var.network_lan.cidr, 0)
    error_message = "kube_vip_cp_address ${var.kube_vip_cp_address} is not inside network_lan (${var.network_lan.cidr})."
  }

  precondition {
    condition     = cidrhost("${var.kube_vip_svc_address}/${local.lan_prefix}", 0) == cidrhost(var.network_lan.cidr, 0)
    error_message = "kube_vip_svc_address ${var.kube_vip_svc_address} is not inside network_lan (${var.network_lan.cidr})."
  }

  # ... and must not collide with any VM's LAN IP.
  precondition {
    condition     = !contains(local.vm_lan_ips, var.kube_vip_cp_address)
    error_message = "kube_vip_cp_address ${var.kube_vip_cp_address} clashes with a VM LAN IP (${join(", ", local.vm_lan_ips)})."
  }

  precondition {
    condition     = !contains(local.vm_lan_ips, var.kube_vip_svc_address)
    error_message = "kube_vip_svc_address ${var.kube_vip_svc_address} clashes with a VM LAN IP (${join(", ", local.vm_lan_ips)})."
  }

  precondition {
    condition     = cidrhost("${var.pihole_svc_address}/${local.lan_prefix}", 0) == cidrhost(var.network_lan.cidr, 0)
    error_message = "pihole_svc_address ${var.pihole_svc_address} is not inside network_lan (${var.network_lan.cidr})."
  }

  precondition {
    condition     = !contains(local.vm_lan_ips, var.pihole_svc_address)
    error_message = "pihole_svc_address ${var.pihole_svc_address} clashes with a VM LAN IP (${join(", ", local.vm_lan_ips)})."
  }
}

output "ssh_config" {
  sensitive = true
  value = join("\n", [for name, h in local.ansible_hosts : <<-EOT
    Host ${name}
      HostName ${h.ansible_host}
      User ${h.ansible_user}
      IdentityFile ${h.ansible_ssh_private_key_file}
      IdentitiesOnly yes
  EOT
  ])
}

output "helmfile_values" {
  value = yamlencode({
    kube_vip_svc_address = var.kube_vip_svc_address
    pihole_svc_address   = var.pihole_svc_address
    dnsmasq_upstream_servers = var.dnsmasq_upstream_servers
    dnsmasq_address_entries  = local.dnsmasq_all_entries
    machines             = local.machines
    backup = {
      s3_endpoint     = "https://${var.hetzner_s3.endpoint}"
      s3_bucket       = minio_s3_bucket.backups.bucket
      s3_access_key   = var.hetzner_s3.access_key # gitleaks:allow
      s3_secret_key   = var.hetzner_s3.secret_key # gitleaks:allow
      restic_password = var.backup_restic_password
    }
    domain               = var.domain
    domain_lan           = var.domain_lan
    network_lan_cidr     = "${cidrhost(var.network_lan.cidr, 0)}/${split("/", var.network_lan.cidr)[1]}"
    proxmox_endpoint_internal = trimsuffix(var.proxmox.endpoint_internal, "/")
    proxmox_cluster_name = var.proxmox_cluster_name
    proxmox_storage_name = var.proxmox_storage_name
    k3s_cluster_cidr = var.k3s_cluster_cidr
    k3s_service_cidr = var.k3s_service_cidr
    csi_tokenid = proxmox_user_token.CSI.id
    csi_tokensecret = trimprefix(proxmox_user_token.CSI.value, "${proxmox_user_token.CSI.id}=")
  })
  sensitive = true
}
