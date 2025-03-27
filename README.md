# Azure Cloudflare Zero Trust Gateway Module

This Terraform module creates an Azure-based Cloudflare Zero Trust Gateway that acts as an ingress traffic pipe for your Azure infrastructure. It sets up a secure, managed tunnel between your Azure environment and Cloudflare's global network, enabling secure access to your internal resources without exposing them directly to the internet.

## Features

- Deploys a Linux VM running Cloudflare Zero Trust Gateway
- Automatically configures Cloudflare tunnel with secure authentication
- Implements managed identity for secure Azure resource access
- Includes Azure AD SSH login support
- Provides automatic cleanup on resource destruction
- Configures necessary network security and access controls

## Prerequisites

- Azure subscription with appropriate permissions
- Cloudflare account with Zero Trust enabled
- Terraform 1.6 or later
- Azure CLI (for local development)
- Cloudflare API token with appropriate permissions

## Usage

### Basic Usage

```hcl
module "cloudflared" {
  source = "path/to/tf-azure-cloudflared"

  resource_group_name = "my-resource-group"
  subnet_id          = "/subscriptions/.../subnets/my-subnet"
  vm_name            = "cloudflared-gateway"
  
  # Cloudflare configuration
  cloudflare_account_id = "your-cloudflare-account-id"
  cloudflare_api_token  = "your-cloudflare-api-token"
  domain_name          = "example.com"
  vnet_cidr           = "10.0.0.0/16"
  
  # Optional ingress rules
  ingress_rules = [
    {
      hostname = "app.example.com"
      service  = "http://10.0.1.10:8080"
    }
  ]
}
```

### Advanced Usage with Custom Settings

```hcl
module "cloudflared" {
  source = "path/to/tf-azure-cloudflared"

  resource_group_name = "my-resource-group"
  subnet_id          = "/subscriptions/.../subnets/my-subnet"
  vm_name            = "cloudflared-gateway"
  
  # Cloudflare configuration
  cloudflare_account_id = "your-cloudflare-account-id"
  cloudflare_api_token  = "your-cloudflare-api-token"
  domain_name          = "example.com"
  vnet_cidr           = "10.0.0.0/16"
  
  # Ingress rules
  ingress_rules = [
    {
      hostname = "app.example.com"
      service  = "http://10.0.1.10:8080"
    },
    {
      hostname = "api.example.com"
      service  = "http://10.0.1.11:3000"
    }
  ]
  
  # Custom tags
  tags = {
    Environment = "Production"
    Project     = "Secure Access"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| resource_group_name | Name of the Azure resource group | string | yes |
| subnet_id | ID of the subnet where the VM will be deployed | string | yes |
| vm_name | Name of the virtual machine running cloudflared | string | no |
| cloudflare_account_id | Your Cloudflare account ID | string | yes |
| cloudflare_api_token | Your Cloudflare API token with appropriate permissions | string | yes |
| domain_name | The domain name to use for the tunnel | string | yes |
| vnet_cidr | The CIDR block of the Azure VNet to route through the tunnel | string | yes |
| ingress_rules | List of ingress rules for the Cloudflare tunnel | list(object) | no |
| tags | Additional tags to apply to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | ID of the created virtual machine |
| vm_private_ip | Private IP address of the virtual machine |
| tunnel_id | ID of the created Cloudflare tunnel |

## Security Considerations

- The module uses managed identity for secure Azure resource access
- SSH access is configured through Azure AD
- Cloudflare tunnel provides secure, encrypted communication
- The VM is deployed in a private subnet with no direct internet access

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📜 License

This module is licensed under the [CC BY-NC 4.0 license](https://creativecommons.org/licenses/by-nc/4.0/).  
You may use, modify, and share this code **for non-commercial purposes only**.

If you wish to use it in a commercial project (e.g., as part of client infrastructure or a paid product), you must obtain a commercial license.

📬 Contact: mathias@monsieurdahlstrom.com