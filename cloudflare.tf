# Generate random secret for the tunnel
resource "random_string" "tunnel_secret" {
  length  = 32
  special = false
  count   = var.tunnel_spec != null ? 1 : 0
}

# Generate random string for resource name suffix
resource "random_string" "tunnel_name_suffix" {
  length  = 8
  special = false
  upper   = false
  count   = var.tunnel_spec != null ? 1 : 0
}

# Create Cloudflare Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  count      = var.tunnel_spec != null ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "azure-tunnel-${random_string.tunnel_name_suffix[0].result}"
  tunnel_secret     = base64sha256(random_string.tunnel_secret[0].result)
}

# Create Tunnel Configuration
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "config" {
  count      = var.tunnel_spec != null ? 1 : 0
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id

  config = {
    # Enable WARP
    warp_routing = {
      enabled = true
    }
    ingress = concat(
      [for rule in var.tunnel_spec.ingress_rules : {
        hostname = "${rule.hostname}.${var.tunnel_spec.domain_name}"
        service  = rule.service
      }],
      [{
        service = "http_status:404"
      }]
    )
  }

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared.tunnel
  ]
}

# Create Tunnel Route for VNet CIDR
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "vnet" {
  count      = var.tunnel_spec != null ? 1 : 0
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id
  network    = var.tunnel_spec.vnet_cidr
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
#   tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id
# }
