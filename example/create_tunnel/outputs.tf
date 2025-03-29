output "tunnel_status" {
  description = "Status of the Cloudflare tunnel"
  value       = module.cloudflared.tunnel_status
} 