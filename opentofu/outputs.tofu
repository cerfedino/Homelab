output "ansible_yaml_inventory" {
  value = yamlencode({
    all = {
      children = {
        k3s_cluster = {
            children = {
                server = {
                    hosts = {
                        for instance in module.vm_k3s :
                        instance.name => {
                            vm_id: instance.vm_id
                            ansible_host = split("/", [for ni in instance.network_interfaces : ni.address if ni.bridge == var.network_internal.bridge][0])[0]
                            ansible_user = instance.username
                            ansible_ssh_private_key_file : instance.ssh_private_key_paths[0]
                        }
                    }
                }
            }
        }
        tailscale_gw = {
          hosts = {
            (module.vm_tailscale.name) = {
              vm_id:  module.vm_tailscale.vm_id
              ansible_host = split("/", [for ni in module.vm_tailscale.network_interfaces : ni.address if ni.bridge == var.network_internal.bridge][0])[0]
              ansible_user = module.vm_tailscale.username
              ansible_ssh_private_key_file : module.vm_tailscale.ssh_private_key_paths[0]
            }
          }
        }
      }
    }
  })
}


output "ansible_group_vars" {
  value = yamlencode({
    kube_vip_cp_address  = var.kube_vip_cp_address
    kube_vip_svc_address = var.kube_vip_svc_address
    k3s_server_lan_ips = [for _, v in var.vm_k3s : cidrhost(var.network_lan.cidr, v.vm_id)]
    network_lan = {
      cidr    = "${cidrhost(var.network_lan.cidr, 0)}/${split("/", var.network_lan.cidr)[1]}"
      bridge  = var.network_lan.bridge
      gateway = var.network_lan.gateway
    }
    network_internal = {
      cidr    = "${cidrhost(var.network_internal.cidr, 0)}/${split("/", var.network_internal.cidr)[1]}"
      bridge = var.network_internal.bridge
      gateway = var.network_internal.gateway
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
}
