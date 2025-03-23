package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFullDeployment(t *testing.T) {
	// Construct the terraform options with default retryable errors
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../examples/integration/full_deployment",
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"cloudflare_account_id": "test-account-id",
			"resource_group_name":   "rg-cloudflared-test",
			"location":             "westeurope",
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
	vmId := terraform.Output(t, terraformOptions, "vm_id")
	nicId := terraform.Output(t, terraformOptions, "nic_id")

	// Verify all resources were created
	assert.NotEmpty(t, tunnelId)
	assert.NotEmpty(t, vmId)
	assert.NotEmpty(t, nicId)
} 