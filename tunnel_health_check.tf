resource "null_resource" "tunnel_health_check" {
  triggers = {
    timestamp = timestamp()
    tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
    # Store script paths in triggers to recreate if scripts change
    bash_script_path = "${path.module}/scripts/check_tunnel_health.sh"
    ps_script_path   = "${path.module}/scripts/check_tunnel_health.ps1"
    # Store OS information for cross-platform support
    is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  }

  # Make sure the bash script is executable on Unix/Linux systems
  provisioner "local-exec" {
    command     = self.triggers.is_windows ? "echo 'Windows detected, skipping chmod'" : "chmod +x ${path.module}/scripts/check_tunnel_health.sh"
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }

  # Run the health check script
  provisioner "local-exec" {
    command = self.triggers.is_windows ? (
      "powershell.exe -ExecutionPolicy Bypass -File ${path.module}/scripts/check_tunnel_health.ps1 -TunnelID '${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}' -CloudflareAccountId '${var.cloudflare_account_id}' -CloudflareApiToken '${var.cloudflare_api_token}'"
      ) : (
      "${path.module}/scripts/check_tunnel_health.sh '${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}' '${var.cloudflare_account_id}' '${var.cloudflare_api_token}'"
    )
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }
} 