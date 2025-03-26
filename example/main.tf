resource "random_string" "rg_name" {
  length = 8
  special = false
  upper = false
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${random_string.rg_name.result}"
  location            = "swedencentral"
}

resource "azurerm_virtual_network" "main" {
  name                = "example-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "virtual_machines" {
  name                 = "virtual-machines"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

module "cloudflared" {
  source = "../"
  domain_name = "monsieurdahlstrom.dev"
  resource_group_name = azurerm_resource_group.example.name
  subnet_id = azurerm_subnet.virtual_machines.id
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token = var.cloudflare_api_token
  vnet_cidr = "10.0.0.0/16"
}

# Add tunnel health check
resource "null_resource" "tunnel_health_check" {
  triggers = {
    timestamp = timestamp()
    tunnel_id = module.cloudflared.cloudflared_tunnel_id
    # Store script paths in triggers to recreate if scripts change
    bash_script_path = "${path.module}/check_tunnel_health.sh"
    ps_script_path   = "${path.module}/check_tunnel_health.ps1"
    # Store OS information for cross-platform support
    is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  }

  # Make sure the bash script is executable on Unix/Linux systems
  provisioner "local-exec" {
    command     = self.triggers.is_windows ? "echo 'Windows detected, skipping chmod'" : "chmod +x ${path.module}/check_tunnel_health.sh"
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }

  # Run the health check script
  provisioner "local-exec" {
    command = self.triggers.is_windows ? (
      "powershell.exe -ExecutionPolicy Bypass -File ${path.module}/check_tunnel_health.ps1 -TunnelID '${module.cloudflared.cloudflared_tunnel_id}' -ResourceGroup '${azurerm_resource_group.example.name}' -VMName '${module.cloudflared.vm_name}' -CloudflareAccountId '${var.cloudflare_account_id}' -CloudflareApiToken '${var.cloudflare_api_token}'"
      ) : (
      "${path.module}/check_tunnel_health.sh '${module.cloudflared.cloudflared_tunnel_id}' '${azurerm_resource_group.example.name}' '${module.cloudflared.vm_name}' '${var.cloudflare_account_id}' '${var.cloudflare_api_token}'"
    )
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }
}

# Add outputs to be used by health check scripts
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}

output "vm_name" {
  value = module.cloudflared.vm_name
}



