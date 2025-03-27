output "vm_id" {
  description = "The ID of the Virtual Machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "The name of the VM running the cloudflared tunnel"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "vm_private_ip" {
  description = "The private IP address of the Virtual Machine"
  value       = azurerm_network_interface.vm.private_ip_address
} 

output "cloudflared_tunnel_id" {
  description = "The ID of the Cloudflared tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
}

output "tunnel_status" {
  description = "Status of the Cloudflare tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.status
}

output "tunnel_health_check" {
  description = "The tunnel health check resource that can be used in depends_on blocks"
  value       = null_resource.tunnel_health_check
}
