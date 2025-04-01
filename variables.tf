variable "vm_name" {
  description = "Name of the virtual machine running cloudflared"
  type        = string
  default     = "vm-cloudflared"
}

variable "tunnel_token_secret" {
  description = "The name of the Key Vault secret containing the tunnel token"
  type        = string
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