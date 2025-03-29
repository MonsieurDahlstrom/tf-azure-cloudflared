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
  resource_group_name = azurerm_resource_group.example.name
  subnet_id = azurerm_subnet.virtual_machines.id
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token = var.cloudflare_api_token
  tunnel_spec = {
    domain_name = "monsieurdahlstrom.dev"
    vnet_cidr = "10.0.0.0/16"
    ingress_rules = [
      {
        hostname = "monsieurdahlstrom.dev"
        service  = "http_status:404"
      }
    ]
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
  depends_on = [module.cloudflared.tunnel_health_check]
}

# Add outputs to be used by health check scripts
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}

output "vm_name" {
  value = module.cloudflared.vm_name
}



