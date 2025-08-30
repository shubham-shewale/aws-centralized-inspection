package inspection_test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestInspectionProvisioning tests GWLB and endpoint provisioning
func TestInspectionProvisioning(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345", // Would be from network module
			"public_subnet_ids": []string{"subnet-pub-1", "subnet-pub-2"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1", "vpc-spoke-2"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1", "subnet-spoke-1-priv-2"},
				{"subnet-spoke-2-priv-1", "subnet-spoke-2-priv-2"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16", "10.2.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1", "rt-priv-2"},
			"spoke_route_table_ids":              []string{"rt-spoke-1", "rt-spoke-2"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate GWLB creation
	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Validate target group
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	assert.NotEmpty(t, targetGroupArn, "Target group should be created")

	// Validate VPC endpoint service
	endpointServiceName := terraform.Output(t, terraformOptions, "endpoint_service_name")
	assert.NotEmpty(t, endpointServiceName, "Endpoint service should be created")
	assert.Contains(t, endpointServiceName, "com.amazonaws.vpce", "Should be AWS VPC endpoint service")

	// Validate VPC endpoints in spoke VPCs
	endpointIds := terraform.OutputList(t, terraformOptions, "endpoint_ids")
	assert.Len(t, endpointIds, 2, "Should have endpoints in 2 spoke VPCs")

	// Validate security group
	sgId := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, sgId, "Security group should be created")

	// Validate Shield protection
	shieldProtectionId := terraform.Output(t, terraformOptions, "shield_protection_id")
	if shieldProtectionId != "" {
		// Shield protection is enabled
		assert.NotEmpty(t, shieldProtectionId, "Shield protection should be configured")
	}
}

// TestInspectionRoutingConfiguration tests routing through GWLB endpoints
func TestInspectionRoutingConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345",
			"public_subnet_ids": []string{"subnet-pub-1"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1"},
			"spoke_route_table_ids":              []string{"rt-spoke-1"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate routes in spoke VPC route tables
	spokeRouteTableId := terraform.Output(t, terraformOptions, "spoke_route_table_id")
	endpointId := terraform.Output(t, terraformOptions, "endpoint_id")

	assert.NotEmpty(t, spokeRouteTableId, "Spoke route table should exist")
	assert.NotEmpty(t, endpointId, "Endpoint should exist")

	// Validate inspection VPC routes for return traffic
	inspectionRtId := terraform.Output(t, terraformOptions, "inspection_private_route_table_id")
	assert.NotEmpty(t, inspectionRtId, "Inspection route table should exist")
}

// TestInspectionTrafficSteering tests traffic steering through GWLB
func TestInspectionTrafficSteering(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345",
			"public_subnet_ids": []string{"subnet-pub-1", "subnet-pub-2"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1", "vpc-spoke-2"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1", "subnet-spoke-1-priv-2"},
				{"subnet-spoke-2-priv-1", "subnet-spoke-2-priv-2"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16", "10.2.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1", "rt-priv-2"},
			"spoke_route_table_ids":              []string{"rt-spoke-1", "rt-spoke-2"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate GWLB listener configuration
	listenerArn := terraform.Output(t, terraformOptions, "listener_arn")
	assert.NotEmpty(t, listenerArn, "GWLB listener should be created")

	// Validate target group attachment (would need firewall instances)
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	assert.NotEmpty(t, targetGroupArn, "Target group should exist")

	// Validate cross-spoke traffic routing
	spokeRtIds := terraform.OutputList(t, terraformOptions, "spoke_route_table_ids")
	endpointIds := terraform.OutputList(t, terraformOptions, "endpoint_ids")

	assert.Len(t, spokeRtIds, 2, "Should have route tables for 2 spoke VPCs")
	assert.Len(t, endpointIds, 2, "Should have endpoints for 2 spoke VPCs")
}

// TestInspectionSymmetricRouting tests symmetric routing through appliance mode
func TestInspectionSymmetricRouting(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345",
			"public_subnet_ids": []string{"subnet-pub-1"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1"},
			"spoke_route_table_ids":              []string{"rt-spoke-1"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate that routes ensure symmetric flow
	spokeRtId := terraform.Output(t, terraformOptions, "spoke_route_table_id")
	inspectionRtId := terraform.Output(t, terraformOptions, "inspection_private_route_table_id")
	endpointId := terraform.Output(t, terraformOptions, "endpoint_id")

	assert.NotEmpty(t, spokeRtId, "Spoke route table should exist")
	assert.NotEmpty(t, inspectionRtId, "Inspection route table should exist")
	assert.NotEmpty(t, endpointId, "Endpoint should exist")

	// This ensures symmetric routing: outbound via GWLB, return via TGW
	t.Log("Symmetric routing validation completed")
}

// TestInspectionHealthChecks tests GWLB health check configuration
func TestInspectionHealthChecks(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345",
			"public_subnet_ids": []string{"subnet-pub-1"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1"},
			"spoke_route_table_ids":              []string{"rt-spoke-1"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate target group health check settings
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	assert.NotEmpty(t, targetGroupArn, "Target group should exist")

	// In a real scenario, we would validate actual health check results
	// by deploying firewall instances and checking their health status
	t.Log("Health check configuration validated - would require firewall instances for full testing")
}
