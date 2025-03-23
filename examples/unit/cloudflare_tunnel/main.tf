terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
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

output "tunnel_id" {
  value = cloudflare_tunnel.tunnel.id
}

output "tunnel_name" {
  value = cloudflare_tunnel.tunnel.name
} 