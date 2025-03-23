package unit

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCloudflareTunnel(t *testing.T) {
	// Construct the terraform options with default retryable errors
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../examples/unit/cloudflare_tunnel",
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"cloudflare_account_id": "test-account-id",
		},
		// Disable colors in Terraform commands so its output is easier to parse
		NoColor: true,
	})

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply". Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the values of output variables
	tunnelId := terraform.Output(t, terraformOptions, "tunnel_id")
	tunnelName := terraform.Output(t, terraformOptions, "tunnel_name")

	// Verify the tunnel was created with the correct name
	assert.Equal(t, "azure-tunnel", tunnelName)
	assert.NotEmpty(t, tunnelId)
} 