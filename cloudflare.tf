# Generate random secret for the tunnel
resource "random_string" "tunnel_secret" {
  length = 32
  special = false
}

# Generate random string for resource name suffix
resource "random_string" "tunnel_name_suffix" {
  length = 8
  special = false
  upper = false
}

# Create Cloudflare Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  account_id = var.cloudflare_account_id
  name       = "azure-tunnel-${random_string.tunnel_name_suffix.result}"
  tunnel_secret     = base64sha256(random_string.tunnel_secret.result)
}

# Create Tunnel Configuration
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
  
  config = {
    # Enable WARP
    warp_routing = {
      enabled = true
    }
    ingress = [
      {
        service = "http_status:404"
      }
    ]
  }

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared.tunnel
  ]
}

# Create Tunnel Route for VNet CIDR
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "vnet" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
  network    = var.vnet_cidr
  comment    = "Route for Azure VNet"

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared_config.config
  ]
}

//TODO: use the cloudflare_zero_trust_tunnel_cloudflared_token when its bug free
// https://github.com/cloudflare/terraform-provider-cloudflare/issues/5009#issuecomment-2642140553
// https://github.com/cloudflare/terraform-provider-cloudflare/issues/5149 
# data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnel" {
#   account_id = var.cloudflare_account_id
#   tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
# }
