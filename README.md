# Azure Cloudflare Zero Trust Gateway Module

This Terraform module creates an Azure-based Cloudflare Zero Trust Gateway that acts as an ingress traffic pipe for your Azure infrastructure. It sets up a secure, managed tunnel between your Azure environment and Cloudflare's global network, enabling secure access to your internal resources without exposing them directly to the internet.

## Features

- Deploys a Linux VM running Cloudflare Zero Trust Gateway
- Uses a pre-configured Cloudflare tunnel token for authentication
- Implements managed identity for secure Azure resource access
- Includes Azure AD SSH login support
- Provides automatic cleanup on resource destruction
- Configures necessary network security and access controls

## Prerequisites

- Azure subscription with appropriate permissions
- Pre-configured Cloudflare tunnel token
- Terraform 1.6 or later
- Azure CLI (for local development)

## Usage

### Basic Usage

```hcl
module "cloudflared" {
  source = "path/to/tf-azure-cloudflared"

  resource_group_name = "my-resource-group"
  subnet_id          = "/subscriptions/.../subnets/my-subnet"
  vm_name            = "cloudflared-gateway"
  
  # Cloudflare configuration
  tunnel_token_secret = "your-cloudflare-tunnel-token"
  
  # Optional tags
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
| tunnel_token_secret | The Cloudflare tunnel token to use for authentication | string | yes |
| tags | Additional tags to apply to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | ID of the created virtual machine |
| vm_name | Name of the VM running the cloudflared tunnel |
| vm_private_ip | Private IP address of the virtual machine |
| vm_health_check | The VM health check resource that can be used in depends_on blocks |

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