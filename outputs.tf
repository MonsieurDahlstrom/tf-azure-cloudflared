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

output "cloudflared_tunnel_id" {
  description = "The ID of the Cloudflared tunnel"
  value       = try(cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id, null)
}

output "tunnel_status" {
  description = "Status of the Cloudflare tunnel"
  value       = try(cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].status, null)
}

output "tunnel_health_check" {
  description = "The tunnel health check resource that can be used in depends_on blocks"
  value       = try(null_resource.tunnel_health_check, null)
}
