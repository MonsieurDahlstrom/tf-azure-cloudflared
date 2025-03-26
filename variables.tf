variable "cloudflare_account_id" {
  description = "The Cloudflare account ID"
  type        = string
}

variable "domain_name" {
  description = "The domain name to use for the tunnel"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet where the VM will be deployed"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules for the Cloudflare tunnel"
  type = list(object({
    hostname = string
    service  = string
  }))
  default = []
}

variable "cloudflare_api_token" {
  description = "The Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "vnet_cidr" {
  description = "The CIDR block of the Azure VNet to route through the tunnel"
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0)) && can(cidrnetmask(var.vnet_cidr))
    error_message = "Must be valid IPv4 CIDR."
  }

  validation {
    condition     = (
      can(regex("^10\\.", var.vnet_cidr)) ||
      can(regex("^172\\.(1[6-9]|2[0-9]|3[0-1])\\.", var.vnet_cidr)) ||
      can(regex("^192\\.168\\.", var.vnet_cidr))
    )
    error_message = "CIDR must be in private IP range (10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16)."
  }
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

variable "vm_name" {
  description = "Name of the virtual machine running cloudflared"
  type        = string
  default     = "vm-cloudflared"
} 