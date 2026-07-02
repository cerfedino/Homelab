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
        tailscale = {
          hosts = {
            tailscale = {
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
}
