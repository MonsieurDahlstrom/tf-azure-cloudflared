config {
  call_module_type = "local"
  force = false
}

# Disable rules that might be too strict
rule "terraform_deprecated_index" {
  enabled = false
}

rule "terraform_unused_declarations" {
  enabled = false
}

rule "terraform_comment_syntax" {
  enabled = false
}

# Disable rules that might conflict with patterns
rule "terraform_documented_outputs" {
  enabled = false
}

rule "terraform_documented_variables" {
  enabled = false
}

# Naming convention rules
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Disable rules that might be too strict for variables
rule "terraform_typed_variables" {
  enabled = false
} 