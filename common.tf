locals {
  default_tags = {
    module     = "tf-azure-cloudflared"
    ManagedBy  = "terraform"
    created_at = formatdate("YYYY-MM-DD HH:mm:ss", timestamp())
  }

  common_tags = merge(local.default_tags, var.tags)
} 