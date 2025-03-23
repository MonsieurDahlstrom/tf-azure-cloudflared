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
    hostname = optional(string)
    service  = string
  }))
  default = [
    {
      service = "http_status:404"
    }
  ]
} 