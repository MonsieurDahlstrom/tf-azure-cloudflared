resource "null_resource" "tunnel_health_check" {

  triggers = merge(
    {
      # Use either the decoded tunnel ID or the created tunnel ID
      tunnel_id = local.tunnel_id
      timestamp = timestamp()
      # Store script paths in triggers to recreate if scripts change
      bash_script_path = "${path.module}/scripts/check_tunnel_health.sh"
      ps_script_path   = "${path.module}/scripts/check_tunnel_health.ps1"
      # Store OS information for cross-platform support
      is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
    },
    # Only include these when tunnel_spec is provided
    var.tunnel_spec != null ? {
      config_id = cloudflare_zero_trust_tunnel_cloudflared_config.config[0].id
      cloudflare_account_id = var.cloudflare_account_id
      cloudflare_api_token = var.cloudflare_api_token
    } : {},
    # Only include these when vnet_cidr is specified
    var.tunnel_spec != null ? (var.tunnel_spec.vnet_cidr != null ? {
      route_id = cloudflare_zero_trust_tunnel_cloudflared_route.vnet[0].id
    } : {}) : {}
  )

  # Make sure the bash script is executable on Unix/Linux systems
  provisioner "local-exec" {
    command     = self.triggers.is_windows ? "echo 'Windows detected, skipping chmod'" : "if [ -f ${path.module}/scripts/check_tunnel_health.sh ]; then chmod +x ${path.module}/scripts/check_tunnel_health.sh; fi"
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }

  # Run the appropriate health check based on what's available
  provisioner "local-exec" {
    command = var.tunnel_spec != null ? (
      self.triggers.is_windows ? (
        "if exist ${path.module}/scripts/check_tunnel_health.ps1 powershell.exe -ExecutionPolicy Bypass -File ${path.module}/scripts/check_tunnel_health.ps1 -TunnelID '${local.tunnel_id}' -CloudflareAccountId '${var.cloudflare_account_id}' -CloudflareApiToken '${var.cloudflare_api_token}'"
      ) : (
        "if [ -f ${path.module}/scripts/check_tunnel_health.sh ]; then ${path.module}/scripts/check_tunnel_health.sh '${local.tunnel_id}' '${var.cloudflare_account_id}' '${var.cloudflare_api_token}'; else echo 'Tunnel ${local.tunnel_id} configuration validated' > /dev/null; fi"
      )
    ) : (
      self.triggers.is_windows ? (
        "echo 'Using existing tunnel ${local.tunnel_id} from token' > NUL"
      ) : (
        "echo 'Using existing tunnel ${local.tunnel_id} from token' > /dev/null"
      )
    )
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }

  # Define a depends_on list based on the input variables
  depends_on =[ azurerm_linux_virtual_machine.vm]
} 