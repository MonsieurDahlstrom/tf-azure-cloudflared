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

# Create a test tunnel for the example
resource "random_string" "tunnel_secret" {
  length  = 32
  special = false
  upper   = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  account_id = var.cloudflare_account_id
  name       = "test-tunnel-${random_string.rg_name.result}"
  secret     = base64sha256(random_string.tunnel_secret.result)
}

locals {
  # Create the tunnel token for the module
  tunnel_token = base64encode(jsonencode({
    "a" : var.cloudflare_account_id,
    "s" : base64sha256(random_string.tunnel_secret.result),
    "t" : cloudflare_zero_trust_tunnel_cloudflared.tunnel.id,
  }))
}

module "cloudflared" {
  source = "../../"
  resource_group_name = azurerm_resource_group.example.name
  subnet_id = azurerm_subnet.virtual_machines.id
  tunnel_token_secret = local.tunnel_token
}

# Example of using the vm_health_check as a dependency
# This ensures the VM is healthy before creating other resources
resource "null_resource" "example_ready_check" {
  triggers = {
    module_check = module.cloudflared.vm_health_check.id
    timestamp = timestamp()
  }
}

# Example of a dependent resource that waits for the VM to be healthy
resource "null_resource" "dependent_resource" {
  triggers = {
    vm_health = null_resource.example_ready_check.id
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'VM is healthy, proceeding with dependent resource creation'"
  }
}
