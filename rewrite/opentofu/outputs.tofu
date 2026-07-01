output "ansible_yaml_inventory" {
  value = yamlencode({
    all = {
      children = {
        k8s = {
          hosts = {
            for instance in module.vm_k8s :
            instance.name => {
              vm_id: instance.vm_id
              ansible_host = split("/", [for ni in instance.network_interfaces : ni.address if ni.bridge == var.network_internal.bridge][0])[0]
              ansible_user = instance.username
              ansible_ssh_private_key_file : instance.ssh_private_key_paths[0]
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
      cidr    = var.network_lan.cidr
      bridge  = var.network_lan.bridge
      gateway = var.network_lan.gateway
    }
    network_internal = {
      cidr   = var.network_internal.cidr
      bridge = var.network_internal.bridge
      gateway = var.network_internal.gateway
    }
  })
}
