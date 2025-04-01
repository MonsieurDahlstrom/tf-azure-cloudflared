# Add outputs to be used by health check scripts
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}

output "vm_name" {
  value = module.cloudflared.vm_name
}

output "vm_health_check" {
  description = "The VM health check resource that can be used in depends_on blocks"
  value       = null_resource.example_ready_check
}
