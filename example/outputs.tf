output "tunnel_health_check" {
  description = "The tunnel health check resource"
  value       = null_resource.tunnel_health_check
}

output "tunnel_status" {
  description = "Status of the Cloudflare tunnel"
  value       = module.cloudflared.tunnel_status
} 