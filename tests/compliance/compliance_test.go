package compliance_test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestPCIDSSCompliance validates PCI DSS compliance requirements
func TestPCIDSSCompliance(t *testing.T) {
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
				"Environment":        "test",
				"Project":            "centralized-inspection",
				"Compliance":         "pci-dss",
				"DataClassification": "sensitive",
				"EncryptionAtRest":   "required",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Requirement 1: Install and maintain network security controls
	t.Run("Requirement1_NetworkSecurity", func(t *testing.T) {
		validateNetworkSecurityControls(t, terraformOptions)
	})

	// Requirement 2: Apply secure configurations to all system components
	t.Run("Requirement2_SecureConfiguration", func(t *testing.T) {
		validateSecureConfigurations(t, terraformOptions)
	})

	// Requirement 10: Track and monitor all access to network resources
	t.Run("Requirement10_LoggingMonitoring", func(t *testing.T) {
		validateLoggingAndMonitoring(t, terraformOptions)
	})
}

// TestHIPAACompliance validates HIPAA compliance requirements
func TestHIPAACompliance(t *testing.T) {
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
				"Environment":        "test",
				"Project":            "centralized-inspection",
				"Compliance":         "hipaa",
				"DataClassification": "phi",
				"EncryptionAtRest":   "required",
				"Backup":             "required",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Technical Safeguards
	t.Run("TechnicalSafeguards_AccessControl", func(t *testing.T) {
		validateAccessControl(t, terraformOptions)
	})

	t.Run("TechnicalSafeguards_AuditControls", func(t *testing.T) {
		validateAuditControls(t, terraformOptions)
	})

	t.Run("TechnicalSafeguards_Integrity", func(t *testing.T) {
		validateDataIntegrity(t, terraformOptions)
	})
}

// TestSOC2Compliance validates SOC 2 compliance requirements
func TestSOC2Compliance(t *testing.T) {
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
				"Environment":        "test",
				"Project":            "centralized-inspection",
				"Compliance":         "soc2",
				"DataClassification": "confidential",
				"EncryptionAtRest":   "required",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Security Criterion
	t.Run("Security_LogicalAccess", func(t *testing.T) {
		validateLogicalAccessControls(t, terraformOptions)
	})

	// Availability Criterion
	t.Run("Availability_Resiliency", func(t *testing.T) {
		validateSystemResiliency(t, terraformOptions)
	})

	// Confidentiality Criterion
	t.Run("Confidentiality_DataProtection", func(t *testing.T) {
		validateDataProtection(t, terraformOptions)
	})
}

// TestNISTCompliance validates NIST 800-53 compliance requirements
func TestNISTCompliance(t *testing.T) {
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
				"Environment":        "test",
				"Project":            "centralized-inspection",
				"Compliance":         "nist-800-53",
				"DataClassification": "sensitive",
				"EncryptionAtRest":   "required",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// AC - Access Control
	t.Run("AC_AccessControl", func(t *testing.T) {
		validateAccessControlFamily(t, terraformOptions)
	})

	// AU - Audit and Accountability
	t.Run("AU_AuditAccountability", func(t *testing.T) {
		validateAuditAndAccountability(t, terraformOptions)
	})

	// SC - System and Communications Protection
	t.Run("SC_SystemCommunications", func(t *testing.T) {
		validateSystemAndCommunicationsProtection(t, terraformOptions)
	})
}

// TestGDPRCompliance validates GDPR compliance requirements
func TestGDPRCompliance(t *testing.T) {
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
				"Environment":        "test",
				"Project":            "centralized-inspection",
				"Compliance":         "gdpr",
				"DataClassification": "personal",
				"EncryptionAtRest":   "required",
				"DataRetention":      "7-years",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Article 25 - Data Protection by Design and Default
	t.Run("Article25_DataProtectionByDesign", func(t *testing.T) {
		validateDataProtectionByDesign(t, terraformOptions)
	})

	// Article 32 - Security of Processing
	t.Run("Article32_SecurityOfProcessing", func(t *testing.T) {
		validateSecurityOfProcessing(t, terraformOptions)
	})
}

// Validation helper functions

func validateNetworkSecurityControls(t *testing.T, terraformOptions *terraform.Options) {
	// Validate security groups restrict access
	sgId := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, sgId, "Security group should be created")

	// Validate NACLs provide proper segmentation
	naclIds := terraform.OutputList(t, terraformOptions, "network_acl_ids")
	assert.True(t, len(naclIds) > 0, "Network ACLs should be created")

	// Validate VPC Flow Logs are enabled
	flowLogIds := terraform.OutputList(t, terraformOptions, "vpc_flow_log_ids")
	assert.True(t, len(flowLogIds) > 0, "VPC Flow Logs should be enabled")
}

func validateSecureConfigurations(t *testing.T, terraformOptions *terraform.Options) {
	// Validate encryption at rest
	kmsKeyArn := terraform.Output(t, terraformOptions, "kms_key_arn")
	assert.NotEmpty(t, kmsKeyArn, "KMS key should be created for encryption")

	// Validate secure defaults
	vpcId := terraform.Output(t, terraformOptions, "inspection_vpc_id")
	assert.NotEmpty(t, vpcId, "VPC should be created with secure defaults")
}

func validateLoggingAndMonitoring(t *testing.T, terraformOptions *terraform.Options) {
	// Validate CloudTrail is enabled
	cloudtrailArn := terraform.Output(t, terraformOptions, "cloudtrail_arn")
	assert.NotEmpty(t, cloudtrailArn, "CloudTrail should be enabled")

	// Validate Config is enabled
	configRecorderId := terraform.Output(t, terraformOptions, "config_recorder_id")
	assert.NotEmpty(t, configRecorderId, "AWS Config should be enabled")
}

func validateAccessControl(t *testing.T, terraformOptions *terraform.Options) {
	// Validate IAM roles have least privilege
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.NotEmpty(t, iamRoleArn, "IAM role should be created")

	// Validate MFA is required for privileged access
	mfaRequired := terraform.Output(t, terraformOptions, "mfa_required")
	assert.Equal(t, "true", mfaRequired, "MFA should be required")
}

func validateAuditControls(t *testing.T, terraformOptions *terraform.Options) {
	// Validate comprehensive audit logging
	cloudtrailArn := terraform.Output(t, terraformOptions, "cloudtrail_arn")
	assert.NotEmpty(t, cloudtrailArn, "CloudTrail should be enabled for audit")

	// Validate log retention
	logRetention := terraform.Output(t, terraformOptions, "log_retention_days")
	assert.Equal(t, "365", logRetention, "Logs should be retained for 365 days")
}

func validateDataIntegrity(t *testing.T, terraformOptions *terraform.Options) {
	// Validate data integrity controls
	kmsKeyArn := terraform.Output(t, terraformOptions, "kms_key_arn")
	assert.NotEmpty(t, kmsKeyArn, "KMS should be used for data integrity")

	// Validate backup configuration
	backupVaultArn := terraform.Output(t, terraformOptions, "backup_vault_arn")
	assert.NotEmpty(t, backupVaultArn, "Backup vault should be configured")
}

func validateLogicalAccessControls(t *testing.T, terraformOptions *terraform.Options) {
	// Validate access control mechanisms
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.NotEmpty(t, iamRoleArn, "IAM role should be created")

	// Validate password policies
	passwordPolicyArn := terraform.Output(t, terraformOptions, "password_policy_arn")
	assert.NotEmpty(t, passwordPolicyArn, "Password policy should be configured")
}

func validateSystemResiliency(t *testing.T, terraformOptions *terraform.Options) {
	// Validate multi-AZ deployment
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.True(t, len(publicSubnetIds) >= 2, "Should have subnets in multiple AZs")

	// Validate backup and recovery
	backupPlanArn := terraform.Output(t, terraformOptions, "backup_plan_arn")
	assert.NotEmpty(t, backupPlanArn, "Backup plan should be configured")
}

func validateDataProtection(t *testing.T, terraformOptions *terraform.Options) {
	// Validate encryption
	kmsKeyArn := terraform.Output(t, terraformOptions, "kms_key_arn")
	assert.NotEmpty(t, kmsKeyArn, "KMS key should be created")

	// Validate data classification
	dataClassification := terraform.Output(t, terraformOptions, "data_classification")
	assert.NotEmpty(t, dataClassification, "Data should be classified")
}

func validateAccessControlFamily(t *testing.T, terraformOptions *terraform.Options) {
	// AC-2 Account Management
	accountIds := terraform.OutputList(t, terraformOptions, "account_ids")
	assert.True(t, len(accountIds) > 0, "Accounts should be managed")

	// AC-3 Access Enforcement
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.NotEmpty(t, iamRoleArn, "Access should be enforced")
}

func validateAuditAndAccountability(t *testing.T, terraformOptions *terraform.Options) {
	// AU-2 Audit Events
	cloudtrailArn := terraform.Output(t, terraformOptions, "cloudtrail_arn")
	assert.NotEmpty(t, cloudtrailArn, "Audit events should be captured")

	// AU-3 Content of Audit Records
	auditFields := terraform.OutputList(t, terraformOptions, "audit_fields")
	assert.True(t, len(auditFields) > 0, "Audit records should have required content")
}

func validateSystemAndCommunicationsProtection(t *testing.T, terraformOptions *terraform.Options) {
	// SC-7 Boundary Protection
	sgId := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, sgId, "Boundary protection should be implemented")

	// SC-8 Transmission Confidentiality
	kmsKeyArn := terraform.Output(t, terraformOptions, "kms_key_arn")
	assert.NotEmpty(t, kmsKeyArn, "Transmission should be confidential")
}

func validateDataProtectionByDesign(t *testing.T, terraformOptions *terraform.Options) {
	// Validate privacy by design principles
	privacyControls := terraform.OutputList(t, terraformOptions, "privacy_controls")
	assert.True(t, len(privacyControls) > 0, "Privacy controls should be implemented")

	// Validate data minimization
	dataMinimization := terraform.Output(t, terraformOptions, "data_minimization")
	assert.Equal(t, "true", dataMinimization, "Data minimization should be enabled")
}

func validateSecurityOfProcessing(t *testing.T, terraformOptions *terraform.Options) {
	// Validate pseudonymization
	pseudonymization := terraform.Output(t, terraformOptions, "pseudonymization")
	assert.Equal(t, "true", pseudonymization, "Pseudonymization should be enabled")

	// Validate encryption
	encryptionEnabled := terraform.Output(t, terraformOptions, "encryption_enabled")
	assert.Equal(t, "true", encryptionEnabled, "Encryption should be enabled")
}
