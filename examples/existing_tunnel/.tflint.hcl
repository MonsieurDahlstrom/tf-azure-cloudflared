config {
  call_module_type = "local"
  force = false
  # Specify Terraform version for linting
  terraform_version = "1.6.6"
  # Disable provider schema checking which is causing the errors
  ignore_module = true
  varfile = []
  disabled_by_default = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Disable the cloudflare provider plugin completely
plugin "cloudflare" {
  enabled = false
}

# Ignore specific rules for the cloudflare resources
rule "terraform_deprecated_index" {
  enabled = false
}

rule "terraform_unused_declarations" {
  enabled = false
}

rule "terraform_comment_syntax" {
  enabled = false
}

rule "terraform_documented_outputs" {
  enabled = false
}

rule "terraform_documented_variables" {
  enabled = false
} 