package tests

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// GetRequiredEnvVar gets an environment variable or fails the test if it's not set
func GetRequiredEnvVar(t *testing.T, name string) string {
	value := os.Getenv(name)
	if value == "" {
		t.Fatalf("Required environment variable %s is not set", name)
	}
	return value
}

// GetTerraformOptions returns common terraform options for testing
func GetTerraformOptions(t *testing.T, terraformDir string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: terraformDir,
		NoColor:     true,
		Vars: map[string]interface{}{
			"cloudflare_account_id": GetRequiredEnvVar(t, "CLOUDFLARE_ACCOUNT_ID"),
		},
	}
} 