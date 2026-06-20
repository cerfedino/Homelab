output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "username" {
  value = var.username
}

output "ipv4_addresses" {
  description = "All IPv4 addresses reported by the guest agent (one list per interface)"
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
}

output "network_interfaces" {
  description = "Configured network interfaces (bridge, address, gateway)"
  value       = var.network_interfaces
}

output "ssh_public_key_paths" {
    description = "SSH pubkey paths"
    value = var.ssh_public_key_paths
}

output "ssh_private_key_paths" {
    description = "SSH privkey paths"
    value = var.ssh_private_key_paths
}