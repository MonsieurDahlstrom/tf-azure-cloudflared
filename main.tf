locals {
  common_tags = {
    Environment = "prod"
    Project     = "cloudflared"
    ManagedBy   = "terraform"
  }
}

# Create Cloudflare Tunnel
resource "cloudflare_tunnel" "tunnel" {
  account_id = var.cloudflare_account_id
  name       = "azure-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

# Generate random secret for the tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Create Tunnel Configuration
resource "cloudflare_tunnel_config" "config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.tunnel.id

  config {
    # Enable WARP
    warp_routing {
      enabled = true
    }

    # Dynamic ingress rules
    dynamic "ingress_rule" {
      for_each = var.ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }
  }
}

# Create Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "cloudflared-nic"
  location            = "westeurope"
  resource_group_name = "rg-cloudflared"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

# Create Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-cloudflared"
  resource_group_name = "rg-cloudflared"
  location            = "westeurope"
  size                = "Standard_B2s"
  admin_username      = "cloudflared"
  admin_password      = "Cloudflared123!" # This should be stored in a secure way in production
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-pro-jammy"
    sku       = "pro-24_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared.deb
    
    # Create directory for cloudflared config
    mkdir -p /etc/cloudflared
    
    # Write tunnel token to config file
    cat > /etc/cloudflared/config.yml << 'CONFIG'
    tunnel: ${cloudflare_tunnel.tunnel.id}
    credentials-file: /etc/cloudflared/credentials.json
    CONFIG
    
    # Write tunnel credentials
    cat > /etc/cloudflared/credentials.json << 'CREDS'
    ${cloudflare_tunnel.tunnel.credentials_file}
    CREDS
    
    # Set proper permissions
    chmod 600 /etc/cloudflared/credentials.json
    
    # Create systemd service
    cat > /etc/systemd/system/cloudflared.service << 'SERVICE'
    [Unit]
    Description=cloudflared
    After=network.target

    [Service]
    TimeoutStartSec=0
    Type=notify
    ExecStart=/usr/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
    Restart=always
    RestartSec=5s

    [Install]
    WantedBy=multi-user.target
    SERVICE
    
    # Enable and start the service
    systemctl enable cloudflared
    systemctl start cloudflared
    EOF
  )

  tags = local.common_tags
}
