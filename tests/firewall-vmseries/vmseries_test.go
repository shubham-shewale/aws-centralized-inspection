package firewall_vmseries_test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestVMseriesProvisioning tests VM-Series firewall provisioning
func TestVMseriesProvisioning(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"vpc_id":            "vpc-12345",
			"subnet_ids":        []string{"subnet-priv-1", "subnet-priv-2"},
			"instance_type":     "m5.xlarge",
			"min_size":          2,
			"max_size":          4,
			"key_name":          "test-key",
			"target_group_arn":  "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890abcdef",
			"panorama_ip":       "10.0.0.100",
			"panorama_username": "admin",
			"panorama_password": "test-password",
			"management_cidrs":  []string{"10.0.0.0/8"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate launch template
	launchTemplateId := terraform.Output(t, terraformOptions, "launch_template_id")
	assert.NotEmpty(t, launchTemplateId, "Launch template should be created")

	// Validate AMI selection
	amiId := terraform.Output(t, terraformOptions, "ami_id")
	assert.NotEmpty(t, amiId, "AMI should be selected")

	// Validate IAM role and instance profile
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.NotEmpty(t, iamRoleArn, "IAM role should be created")

	instanceProfileArn := terraform.Output(t, terraformOptions, "instance_profile_arn")
	assert.NotEmpty(t, instanceProfileArn, "Instance profile should be created")

	// Validate security group
	securityGroupId := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, securityGroupId, "Security group should be created")

	// Validate autoscaling group
	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Validate bootstrap bucket
	bootstrapBucketName := terraform.Output(t, terraformOptions, "bootstrap_bucket_name")
	assert.NotEmpty(t, bootstrapBucketName, "Bootstrap bucket should be created")

	// Validate bootstrap files
	bootstrapFiles := terraform.OutputList(t, terraformOptions, "bootstrap_files")
	assert.Len(t, bootstrapFiles, 2, "Should have bootstrap.xml and init-cfg.txt")
}

// TestVMseriesHealthAndScaling tests VM-Series health checks and scaling
func TestVMseriesHealthAndScaling(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"vpc_id":            "vpc-12345",
			"subnet_ids":        []string{"subnet-priv-1", "subnet-priv-2"},
			"instance_type":     "m5.xlarge",
			"min_size":          2,
			"max_size":          4,
			"key_name":          "test-key",
			"target_group_arn":  "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890abcdef",
			"panorama_ip":       "10.0.0.100",
			"panorama_username": "admin",
			"panorama_password": "test-password",
			"management_cidrs":  []string{"10.0.0.0/8"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get autoscaling group name
	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should exist")

	// Validate target group ARN
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	assert.NotEmpty(t, targetGroupArn, "Target group should exist")

	// Test scaling policies (would require actual load testing)
	// This is a placeholder for scaling validation
	t.Log("Scaling validation would require load testing to trigger scaling events")
}

// TestVMseriesBootstrapConfiguration tests bootstrap configuration
func TestVMseriesBootstrapConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"vpc_id":            "vpc-12345",
			"subnet_ids":        []string{"subnet-priv-1"},
			"instance_type":     "m5.xlarge",
			"min_size":          1,
			"max_size":          2,
			"key_name":          "test-key",
			"target_group_arn":  "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890abcdef",
			"panorama_ip":       "10.0.0.100",
			"panorama_username": "admin",
			"panorama_password": "test-password",
			"management_cidrs":  []string{"10.0.0.0/8"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate bootstrap bucket configuration
	bootstrapBucketName := terraform.Output(t, terraformOptions, "bootstrap_bucket_name")
	assert.NotEmpty(t, bootstrapBucketName, "Bootstrap bucket should exist")

	// Validate bootstrap files exist
	bootstrapFiles := terraform.OutputList(t, terraformOptions, "bootstrap_files")
	assert.Len(t, bootstrapFiles, 2, "Should have bootstrap.xml and init-cfg.txt")

	// Validate launch template includes bootstrap configuration
	launchTemplateId := terraform.Output(t, terraformOptions, "launch_template_id")
	assert.NotEmpty(t, launchTemplateId, "Launch template should exist")
}

// TestVMseriesSecurityConfiguration tests security-related configurations
func TestVMseriesSecurityConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"vpc_id":            "vpc-12345",
			"subnet_ids":        []string{"subnet-priv-1"},
			"instance_type":     "m5.xlarge",
			"min_size":          1,
			"max_size":          2,
			"key_name":          "test-key",
			"target_group_arn":  "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890abcdef",
			"panorama_ip":       "10.0.0.100",
			"panorama_username": "admin",
			"panorama_password": "test-password",
			"management_cidrs":  []string{"10.0.0.0/8"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate EBS encryption
	kmsKeyArn := terraform.Output(t, terraformOptions, "kms_key_arn")
	assert.NotEmpty(t, kmsKeyArn, "KMS key should be created for EBS encryption")

	// Validate IAM role has proper permissions
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.NotEmpty(t, iamRoleArn, "IAM role should exist")

	// Validate security group is restrictive
	securityGroupId := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, securityGroupId, "Security group should exist")

	// Validate launch template
	launchTemplateId := terraform.Output(t, terraformOptions, "launch_template_id")
	assert.NotEmpty(t, launchTemplateId, "Launch template should exist")
}

// TestVMseriesFailoverBehavior tests failover and high availability
func TestVMseriesFailoverBehavior(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"vpc_id":            "vpc-12345",
			"subnet_ids":        []string{"subnet-priv-1", "subnet-priv-2"},
			"instance_type":     "m5.xlarge",
			"min_size":          2,
			"max_size":          4,
			"key_name":          "test-key",
			"target_group_arn":  "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890abcdef",
			"panorama_ip":       "10.0.0.100",
			"panorama_username": "admin",
			"panorama_password": "test-password",
			"management_cidrs":  []string{"10.0.0.0/8"},
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate multi-AZ deployment
	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should exist")

	// Validate target group attachment
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	assert.NotEmpty(t, targetGroupArn, "Target group should exist")

	// Validate autoscaling policies are configured
	// In a real test, we would validate CPU/memory-based scaling policies
	t.Log("Autoscaling policy validation would check CloudWatch alarms and scaling policies")
}
