output "vm_id" {
  description = "The ID of the Virtual Machine"
  value       = try(azurerm_linux_virtual_machine.vm.id, null)
}

output "vm_name" {
  description = "The name of the VM running the cloudflared tunnel"
  value       = try(azurerm_linux_virtual_machine.vm.name, null)
}

output "vm_private_ip" {
  description = "The private IP address of the Virtual Machine"
  value       = try(azurerm_network_interface.vm.private_ip_address, null)
}

output "vm_health_check" {
  description = "The VM health check resource that can be used in depends_on blocks"
  value       = null_resource.vm_health_check
}
