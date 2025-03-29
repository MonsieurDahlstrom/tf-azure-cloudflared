variable "cloudflare_account_id" {
  description = "The Cloudflare account ID"
  type        = string
}

variable "cloudflare_api_token" {
  description = "The Cloudflare API token"
  type        = string
}

variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "client_id" {
  description = "The Azure client ID"
  type        = string
} 

variable "client_secret" {
  description = "The Azure client secret"
  type        = string
  default     = null
} 

variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

variable "use_oidc" {
  description = "Whether to use OIDC for authentication"
  type        = bool
  default     = false
}
