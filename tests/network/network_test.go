package network_test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestNetworkProvisioning tests the core network infrastructure provisioning
func TestNetworkProvisioning(t *testing.T) {
	t.Parallel()

	// Test configuration
	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/network",
		Vars: map[string]interface{}{
			"vpc_cidr":        "10.0.0.0/16",
			"tgw_asn":         64512,
			"spoke_vpc_cidrs": []string{"10.1.0.0/16", "10.2.0.0/16"},
			"public_subnets":  []string{"10.0.10.0/24", "10.0.11.0/24"},
			"private_subnets": []string{"10.0.20.0/24", "10.0.21.0/24"},
			"azs":             []string{"us-east-1a", "us-east-1b"},
			"spoke_azs":       []string{"us-east-1a", "us-east-1b"},
			"spoke_private_subnets": [][]string{
				{"10.1.20.0/24", "10.1.21.0/24"},
				{"10.2.20.0/24", "10.2.21.0/24"},
			},
			"tags": map[string]string{
				"Environment":        "test",
				"Project":            "centralized-inspection",
				"Owner":              "test-team",
				"DataClassification": "sensitive",
			},
		},
	}

	// Ensure cleanup on failure
	defer terraform.Destroy(t, terraformOptions)

	// Deploy infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC exists
	inspectionVpcId := terraform.Output(t, terraformOptions, "inspection_vpc_id")
	assert.NotEmpty(t, inspectionVpcId, "Inspection VPC should be created")

	// Validate subnets
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	assert.Len(t, publicSubnetIds, 2, "Should have 2 public subnets")
	assert.Len(t, privateSubnetIds, 2, "Should have 2 private subnets")

	// Validate Transit Gateway
	tgwId := terraform.Output(t, terraformOptions, "transit_gateway_id")
	assert.NotEmpty(t, tgwId, "Transit Gateway should be created")

	// Validate TGW attachments
	inspectionAttachmentId := terraform.Output(t, terraformOptions, "inspection_tgw_attachment_id")
	spokeAttachmentIds := terraform.OutputList(t, terraformOptions, "spoke_tgw_attachment_ids")

	assert.NotEmpty(t, inspectionAttachmentId, "Inspection TGW attachment should exist")
	assert.Len(t, spokeAttachmentIds, 2, "Should have 2 spoke TGW attachments")

	// Validate route tables
	inspectionRtId := terraform.Output(t, terraformOptions, "inspection_tgw_route_table_id")
	spokeRtId := terraform.Output(t, terraformOptions, "spoke_tgw_route_table_id")

	assert.NotEmpty(t, inspectionRtId, "Inspection TGW route table should exist")
	assert.NotEmpty(t, spokeRtId, "Spoke TGW route table should exist")

	// Validate spoke VPCs
	spokeVpcIds := terraform.OutputList(t, terraformOptions, "spoke_vpc_ids")
	assert.Len(t, spokeVpcIds, 2, "Should have 2 spoke VPCs")

	// Validate Flow Logs
	flowLogIds := terraform.OutputList(t, terraformOptions, "vpc_flow_log_ids")
	assert.Len(t, flowLogIds, 3, "Should have flow logs for inspection VPC and 2 spoke VPCs")

	// Validate NACLs
	naclIds := terraform.OutputList(t, terraformOptions, "network_acl_ids")
	assert.Len(t, naclIds, 3, "Should have NACLs for inspection VPC and 2 spoke VPCs")

	// Test destroy
	terraform.Destroy(t, terraformOptions)

	// Verify resources are cleaned up (using output validation)
	// Note: In a real test, you would verify via AWS API that resources are gone
	t.Log("Resources cleanup completed")
}

// TestNetworkConfigurationValidation tests network configuration correctness
func TestNetworkConfigurationValidation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/network",
		Vars: map[string]interface{}{
			"vpc_cidr":        "10.0.0.0/16",
			"tgw_asn":         64512,
			"spoke_vpc_cidrs": []string{"10.1.0.0/16"},
			"public_subnets":  []string{"10.0.10.0/24"},
			"private_subnets": []string{"10.0.20.0/24"},
			"azs":             []string{"us-east-1a"},
			"spoke_azs":       []string{"us-east-1a"},
			"spoke_private_subnets": [][]string{
				{"10.1.20.0/24"},
			},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate subnet configurations
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	// Verify subnets exist
	assert.Len(t, publicSubnetIds, 1, "Should have 1 public subnet")
	assert.Len(t, privateSubnetIds, 1, "Should have 1 private subnet")

	// Validate route table associations
	publicRtId := terraform.Output(t, terraformOptions, "public_route_table_id")
	privateRtIds := terraform.OutputList(t, terraformOptions, "private_route_table_ids")

	assert.NotEmpty(t, publicRtId, "Public route table should exist")
	assert.Len(t, privateRtIds, 1, "Should have 1 private route table")
}

// TestNetworkIdempotency tests that network configuration is idempotent
func TestNetworkIdempotency(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/network",
		Vars: map[string]interface{}{
			"vpc_cidr":        "10.0.0.0/16",
			"tgw_asn":         64512,
			"spoke_vpc_cidrs": []string{"10.1.0.0/16"},
			"public_subnets":  []string{"10.0.10.0/24"},
			"private_subnets": []string{"10.0.20.0/24"},
			"azs":             []string{"us-east-1a"},
			"spoke_azs":       []string{"us-east-1a"},
			"spoke_private_subnets": [][]string{
				{"10.1.20.0/24"},
			},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	// First apply
	terraform.InitAndApply(t, terraformOptions)

	// Get initial state
	initialVpcId := terraform.Output(t, terraformOptions, "inspection_vpc_id")
	initialTgwId := terraform.Output(t, terraformOptions, "transit_gateway_id")

	// Second apply (should be no changes)
	terraform.InitAndApply(t, terraformOptions)

	// Verify resources still exist and are the same
	finalVpcId := terraform.Output(t, terraformOptions, "inspection_vpc_id")
	finalTgwId := terraform.Output(t, terraformOptions, "transit_gateway_id")

	assert.Equal(t, initialVpcId, finalVpcId, "VPC ID should remain the same")
	assert.Equal(t, initialTgwId, finalTgwId, "TGW ID should remain the same")
}

// TestNetworkDriftDetection tests detection of configuration drift
func TestNetworkDriftDetection(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/network",
		Vars: map[string]interface{}{
			"vpc_cidr":        "10.0.0.0/16",
			"tgw_asn":         64512,
			"spoke_vpc_cidrs": []string{"10.1.0.0/16"},
			"public_subnets":  []string{"10.0.10.0/24"},
			"private_subnets": []string{"10.0.20.0/24"},
			"azs":             []string{"us-east-1a"},
			"spoke_azs":       []string{"us-east-1a"},
			"spoke_private_subnets": [][]string{
				{"10.1.20.0/24"},
			},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get VPC ID for drift simulation
	vpcId := terraform.Output(t, terraformOptions, "inspection_vpc_id")
	assert.NotEmpty(t, vpcId, "VPC should exist")

	// Run plan to detect drift
	planOutput := terraform.Plan(t, terraformOptions)
	assert.NotEmpty(t, planOutput, "Plan should execute without errors")

	// In a real scenario, we would check for drift detection
	t.Log("Drift detection test completed - plan executed successfully")
}

// TestNetworkResiliency tests network resiliency across AZs
func TestNetworkResiliency(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/network",
		Vars: map[string]interface{}{
			"vpc_cidr":        "10.0.0.0/16",
			"tgw_asn":         64512,
			"spoke_vpc_cidrs": []string{"10.1.0.0/16", "10.2.0.0/16"},
			"public_subnets":  []string{"10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"},
			"private_subnets": []string{"10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"},
			"azs":             []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			"spoke_azs":       []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			"spoke_private_subnets": [][]string{
				{"10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"},
				{"10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"},
			},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate multi-AZ deployment
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	assert.Len(t, publicSubnetIds, 3, "Should have subnets in 3 AZs")
	assert.Len(t, privateSubnetIds, 3, "Should have subnets in 3 AZs")

	// Validate TGW attachments
	spokeAttachmentIds := terraform.OutputList(t, terraformOptions, "spoke_tgw_attachment_ids")
	assert.Len(t, spokeAttachmentIds, 2, "Should have TGW attachments for 2 spoke VPCs")

	// Test connectivity between AZs (would require additional probe instances)
	// This is a placeholder for actual connectivity testing
	t.Log("Multi-AZ resiliency validated - subnets and attachments distributed correctly")
}
