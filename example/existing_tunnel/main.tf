resource "random_string" "rg_name" {
  length = 8
  special = false
  upper = false
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${random_string.rg_name.result}"
  location = "swedencentral"
}

resource "azurerm_virtual_network" "main" {
  name                = "example-vnet-${random_string.rg_name.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "virtual_machines" {
  name                 = "virtual-machines-${random_string.rg_name.result}"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "random_string" "tunnel_token_secret" {
  length = 32
  special = false
  upper = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel_token_secret" {
  name       = "tunnel-token-secret-${random_string.rg_name.result}"
  tunnel_secret     = base64sha256(random_string.tunnel_token_secret.result)
  account_id = var.cloudflare_account_id
}

locals {
  # Set the tunnel token value based on available inputs
  cloudflare_tunnel_token = base64encode(jsonencode({
    "a" : var.cloudflare_account_id,
    "s" : base64sha256(random_string.tunnel_token_secret.result),
    "t" : cloudflare_zero_trust_tunnel_cloudflared.tunnel_token_secret.id,
  }))
}

module "cloudflared" {
  source = "../../"
  resource_group_name = azurerm_resource_group.example.name
  subnet_id = azurerm_subnet.virtual_machines.id
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token = var.cloudflare_api_token
  tunnel_token_secret = local.cloudflare_tunnel_token
}

# Remove the redundant null_resource in the example
resource "null_resource" "example_ready_check" {
  # This is just a wrapper to demonstrate dependencies 
  # that relies on the module's health check
  triggers = {
    module_check = module.cloudflared.tunnel_health_check.id
    timestamp = timestamp()
  }
}

# Example of using the tunnel_health_check as a dependency
# This ensures the tunnel is healthy before creating other resources
resource "azurerm_kubernetes_cluster" "example" {
  count               = 0  # Set to 1 to actually create the cluster
  name                = "example-aks"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "exampleaks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  # Ensure the tunnel is healthy before creating the AKS cluster
  depends_on = [null_resource.example_ready_check]
}

# Add outputs to be used by health check scripts
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}

output "vm_name" {
  value = module.cloudflared.vm_name
}

output "tunnel_health_check" {
  description = "The tunnel health check resource that can be used in depends_on blocks"
  value       = null_resource.example_ready_check
}



