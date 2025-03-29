locals {
  default_tags = {
    module    = "tf-azure-cloudflared"
    ManagedBy = "terraform"
  }

  common_tags = merge(local.default_tags, var.tags)
} 