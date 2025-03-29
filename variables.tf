variable "cloudflare_account_id" {
  description = "The Cloudflare account ID"
  type        = string
}

variable "cloudflare_api_token" {
  description = "The Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "tunnel_spec" {
  description = "Specifications for the Cloudflare tunnel"
  type = object({
    domain_name  = string
    ingress_rules = list(object({
      hostname = string
      service  = string
    }))
    vnet_cidr = optional(string)
  })
  sensitive = true
  default = null

  validation {
    condition = var.tunnel_spec == null ? true : (
      var.tunnel_spec.vnet_cidr == null ? true : 
      can(cidrhost(var.tunnel_spec.vnet_cidr, 0)) && can(cidrnetmask(var.tunnel_spec.vnet_cidr))
    )
    error_message = "Must be valid IPv4 CIDR."
  }

  validation {
    condition = var.tunnel_spec == null ? true : (
      var.tunnel_spec.vnet_cidr == null ? true :
      (
        can(regex("^10\\.", var.tunnel_spec.vnet_cidr)) ||
        can(regex("^172\\.(1[6-9]|2[0-9]|3[0-1])\\.", var.tunnel_spec.vnet_cidr)) ||
        can(regex("^192\\.168\\.", var.tunnel_spec.vnet_cidr))
      )
    )
    error_message = "CIDR must be in private IP range (10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16)."
  }
}

variable "vm_name" {
  description = "Name of the virtual machine running cloudflared"
  type        = string
  default     = "vm-cloudflared"
}

variable "tunnel_token_secret" {
  description = "The name of the Key Vault secret containing the tunnel token"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "The ID of the subnet where the VM will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  # Validation for token configuration
  validate_token_config = alltrue([
    # Case 1: Ensure we don't have both token sources
    !(var.tunnel_token_secret != null && var.tunnel_spec != null),
    # Case 2: Ensure we have at least one token source
    var.tunnel_token_secret != null || var.tunnel_spec != null
  ])

  # Fail if validation fails
  token_validation_check = local.validate_token_config ? true : tobool("Either tunnel_token_secret OR tunnel_spec must be provided, but not both")
} 