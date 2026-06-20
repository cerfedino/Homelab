
output "ansible_yaml_inventory" {
  value = yamlencode({
    all = {
      children = {
        k8s = {
          hosts = {
            for instance in module.vm_k8s :
            instance.name => {
              ansible_host = split("/", [for ni in instance.network_interfaces : ni.address if ni.bridge == "vmbr1"][0])[0]
              ansible_user = instance.username
              ansible_ssh_private_key_file: instance.ssh_private_key_paths[0]
            }
          }
        }
        tailscale = {
          hosts = {
            tailscale = {
              ansible_host = split("/", [for ni in module.vm_tailscale.network_interfaces : ni.address if ni.bridge == "vmbr1"][0])[0]
              ansible_user = module.vm_tailscale.username
              ansible_ssh_private_key_file: module.vm_tailscale.ssh_private_key_paths[0]
            }
          }
        }
      }
    }
  })
}