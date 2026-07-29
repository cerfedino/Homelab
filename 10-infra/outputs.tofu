output "ansible_yaml_inventory" {
  sensitive = true
  value = yamlencode({
    all = {
      children = {
        k3s_cluster = {
            children = {
                server = {
                    hosts = {
                        for k, v in var.vm_k3s :
                        proxmox_virtual_environment_vm.this[k].name => {
                            ansible_host = split("/", [for ni in local.vm_network_interfaces[k] : ni.address if ni.bridge == var.network_lan.bridge][0])[0]
                            ansible_user = var.vm_username
                            ansible_ssh_private_key_file : "${var.REPO_ROOT}/${v.ssh_private_key_paths[0]}"

                            vm_id = proxmox_virtual_environment_vm.this[k].vm_id
                            proxmox_node_name = v.node_name
                            ip_lan = split("/", [for ni in local.vm_network_interfaces[k] : ni.address if ni.bridge == var.network_lan.bridge][0])[0]
                            ip_internal = split("/", [for ni in local.vm_network_interfaces[k] : ni.address if ni.bridge == var.network_internal.bridge][0])[0]

                        }
                    }
                }
            },
            vars = {
                kube_vip_cp_address  = var.kube_vip_cp_address
                kube_vip_svc_address = var.kube_vip_svc_address
                k3s_server_lan_ips = [for _, v in var.vm_k3s : cidrhost(var.network_lan.cidr, v.vm_id)]
                proxmox_cluster_name = var.proxmox_cluster_name
            }
        }
        tailscale_gw = {
          hosts = {
            (proxmox_virtual_environment_vm.this["tailscale"].name) = {
              vm_id:  proxmox_virtual_environment_vm.this["tailscale"].vm_id

              ansible_host = split("/", [for ni in local.vm_network_interfaces["tailscale"] : ni.address if ni.bridge == var.network_lan.bridge][0])[0]


              ansible_host_lan = split("/", [for ni in local.vm_network_interfaces["tailscale"] : ni.address if ni.bridge == var.network_lan.bridge][0])[0]

              ansible_host_internal = split("/", [for ni in local.vm_network_interfaces["tailscale"] : ni.address if ni.bridge == var.network_internal.bridge][0])[0]

              ip_internal = split("/", [for ni in local.vm_network_interfaces["tailscale"] : ni.address if ni.bridge == var.network_internal.bridge][0])[0]

              ansible_user = var.vm_username

              ansible_ssh_private_key_file : "${var.REPO_ROOT}/${var.vm_tailscale.ssh_private_key_paths[0]}"
            }
          }
        }
      }
      vars: {
        dnsmasq_upstream_servers = var.dnsmasq_upstream_servers
        dnsmasq_address_entries  = var.dnsmasq_address_entries
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

output "helmfile_values" {
  value = yamlencode({
    kube_vip_svc_address = var.kube_vip_svc_address
    pihole_svc_address   = var.pihole_svc_address
    dnsmasq_upstream_servers = var.dnsmasq_upstream_servers
    dnsmasq_address_entries  = var.dnsmasq_address_entries
    domain               = var.domain
    domain_lan           = var.domain_lan
    proxmox_endpoint_internal = trimsuffix(var.proxmox.endpoint_internal, "/")
    proxmox_cluster_name = var.proxmox_cluster_name
    proxmox_storage_name = var.proxmox_storage_name
    csi_tokenid = proxmox_user_token.CSI.id
    csi_tokensecret = trimprefix(proxmox_user_token.CSI.value, "${proxmox_user_token.CSI.id}=")
  })
  sensitive = true
}
