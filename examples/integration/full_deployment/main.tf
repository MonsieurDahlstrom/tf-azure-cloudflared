terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = "test-token" # This is a dummy token for testing
}

# Generate random secret for the tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Create Cloudflare Tunnel
resource "cloudflare_tunnel" "tunnel" {
  account_id = var.cloudflare_account_id
  name       = "azure-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

# Create Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "cloudflared-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "cloudflared-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6eNtGpNGwstc...." # Dummy key for testing
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "cloudflared-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Create Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "cloudflared-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

output "tunnel_id" {
  value = cloudflare_tunnel.tunnel.id
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}

output "nic_id" {
  value = azurerm_network_interface.vm.id
} 