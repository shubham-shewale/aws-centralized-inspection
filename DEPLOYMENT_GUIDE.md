# AWS Centralized Traffic Inspection - Deployment Guide

This comprehensive deployment guide provides step-by-step instructions for deploying the AWS centralized traffic inspection architecture using Palo Alto firewalls.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Configuration](#configuration)
4. [Deployment](#deployment)
5. [Validation](#validation)
6. [Post-Deployment](#post-deployment)
7. [Maintenance](#maintenance)

## Prerequisites

### Required Tools and Versions

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.5.0 | Infrastructure as Code |
| AWS CLI | >= 2.0 | AWS API access |
| Git | >= 2.0 | Version control |
| Make | >= 3.0 | Automation (optional) |
| jq | >= 1.6 | JSON processing |

### AWS Account Requirements

#### 1. Account Structure
```
Security/Network Account (Centralized Inspection)
├── Inspection VPC
├── Transit Gateway
└── Firewall Resources

Application Account(s) (Spoke VPCs)
├── Application VPCs
├── GWLB Endpoints
└── Application Resources
```

#### 2. Required AWS Permissions

**For Security/Network Account:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "iam:*",
        "s3:*",
        "dynamodb:*",
        "logs:*",
        "cloudwatch:*",
        "kms:*",
        "autoscaling:*",
        "ssm:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**For Application Accounts:**
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:CreateVpcEndpoint",
    "ec2:DescribeVpcEndpoints",
    "ec2:ModifyVpcEndpoint",
    "ec2:DeleteVpcEndpoints",
    "ec2:CreateVpcEndpointServiceConfiguration",
    "ec2:DescribeVpcEndpointServiceConfigurations"
  ],
  "Resource": "*"
}
```

### Palo Alto Networks Requirements

#### For VM-Series Deployment
- **Panorama Server**: Accessible from AWS environment
- **Auth Codes**: Valid VM-Series license keys
- **Template/Device Group**: Pre-configured in Panorama

#### For Cloud NGFW Deployment
- **Cloud NGFW Subscription**: Active subscription
- **Rulestack Permissions**: Ability to create and manage rulestacks

## Environment Setup

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-org/aws-centralized-inspection.git
cd aws-centralized-inspection

# Verify structure
ls -la
```

### Step 2: Configure AWS Credentials

#### Option A: AWS CLI Configuration
```bash
# Configure AWS CLI
aws configure --profile inspection-admin

# Set environment variables
export AWS_PROFILE=inspection-admin
export AWS_REGION=us-east-1
```

#### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

#### Option C: IAM Roles (Recommended for Production)
```bash
# Assume role for cross-account access
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/InspectionDeploymentRole \
  --role-session-name deployment-session
```

### Step 3: Initialize Terraform

```bash
# Navigate to live directory
cd live

# Initialize Terraform
terraform init

# Verify initialization
terraform version
```

### Step 4: Configure Remote State (Production)

```bash
# Create S3 bucket for state (one-time setup)
aws s3 mb s3://your-inspection-state-bucket --region us-east-1

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name inspection-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Configuration

### Step 1: Choose Inspection Engine

#### VM-Series Configuration
```hcl
# envs/vmseries.tfvars
inspection_engine = "vmseries"
vmseries_version = "10.2.0"
vmseries_instance_type = "m5.xlarge"
vmseries_min_size = 2
vmseries_max_size = 4
panos_hostname = "panorama.yourdomain.com"
panos_username = "admin"
# panos_password set via TF_VAR_panos_password
```

#### Cloud NGFW Configuration
```hcl
# envs/cloudngfw.tfvars
inspection_engine = "cloudngfw"
cloudngfw_rule_stack_name = "inspection-rule-stack"
```

### Step 2: Network Configuration

#### Basic Network Setup
```hcl
# Core network settings
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
tgw_asn = 64512

# Spoke VPCs
spoke_vpc_cidrs = [
  "10.1.0.0/16",  # Development
  "10.2.0.0/16",  # Staging
  "10.3.0.0/16"   # Production
]

# Availability zones
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
```

#### Advanced Network Configuration
```hcl
# Custom subnet configuration
public_subnets = [
  "10.0.10.0/24",  # AZ-1
  "10.0.11.0/24",  # AZ-2
  "10.0.12.0/24"   # AZ-3
]

private_subnets = [
  "10.0.20.0/24",  # AZ-1
  "10.0.21.0/24",  # AZ-2
  "10.0.22.0/24"   # AZ-3
]

# DNS and DHCP configuration
enable_dns_hostnames = true
enable_dns_support = true
dhcp_options_domain_name = "yourdomain.com"
```

### Step 3: Security Configuration

#### Firewall Rules Example
```hcl
# Security rules for PAN-OS
security_rules = [
  {
    name = "allow-web-traffic"
    action = "allow"
    source_zones = ["trust"]
    destination_zones = ["untrust"]
    source_addresses = ["10.1.0.0/16", "10.2.0.0/16"]
    destination_addresses = ["0.0.0.0/0"]
    applications = ["web-browsing", "ssl"]
    services = ["service-http", "service-https"]
  },
  {
    name = "allow-ssh"
    action = "allow"
    source_zones = ["trust"]
    destination_zones = ["untrust"]
    source_addresses = ["10.0.0.0/8"]
    destination_addresses = ["0.0.0.0/0"]
    applications = ["ssh"]
    services = ["application-default"]
  }
]
```

#### Tagging Strategy
```hcl
tags = {
  Environment   = "production"
  Project       = "centralized-inspection"
  Owner         = "security-team"
  CostCenter    = "security-operations"
  Compliance    = "pci-dss"
  Backup        = "daily"
  DataClassification = "sensitive"
}
```

### Step 4: Observability Configuration

#### Flow Logs Configuration
```hcl
# Enable flow logs
enable_flow_logs = true
flow_logs_retention_days = 30

# S3 bucket for logs
flow_logs_s3_bucket = "inspection-flow-logs-20231201"
flow_logs_s3_prefix = "vpc-flow-logs/"

# CloudWatch configuration
flow_logs_cloudwatch_log_group = "/aws/vpc/flow-logs/inspection"
```

#### Traffic Mirroring (Optional)
```hcl
# Enable traffic mirroring for deep inspection
enable_traffic_mirroring = true
traffic_mirror_target_nlb = "inspection-mirror-nlb"

# Mirror filters
mirror_filters = [
  {
    name = "http-traffic"
    rules = [
      {
        destination_cidr = "0.0.0.0/0"
        source_cidr = "10.0.0.0/8"
        protocol = 6
        destination_port = 80
        source_port = 0
      }
    ]
  }
]
```

### Step 5: Cost Optimization

#### Development Environment
```hcl
# Cost-optimized settings for dev
vmseries_min_size = 1
vmseries_max_size = 2
enable_flow_logs = false
enable_traffic_mirroring = false
```

#### Production Environment
```hcl
# Production settings
vmseries_min_size = 3
vmseries_max_size = 6
enable_flow_logs = true
enable_traffic_mirroring = true
```

## Deployment

### Phase 1: Planning

#### 1. Validate Configuration
```bash
# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file=../envs/dev.tfvars -out=tfplan
```

#### 2. Review Plan Output
```bash
# Review planned changes
terraform show tfplan

# Check for any warnings or errors
terraform plan -var-file=../envs/dev.tfvars | grep -E "(Error|Warning)"
```

#### 3. Cost Estimation
```bash
# Estimate costs (requires AWS Cost Explorer)
terraform plan -var-file=../envs/dev.tfvars -out=tfplan
terraform show -json tfplan | jq '.planned_values.root_module.resources[] | select(.type == "aws_instance")'
```

### Phase 2: Initial Deployment

#### 1. Deploy Network Infrastructure
```bash
# Deploy only network components first
terraform apply -target=module.network -var-file=../envs/dev.tfvars
```

#### 2. Deploy Inspection Components
```bash
# Deploy GWLB and endpoints
terraform apply -target=module.inspection -var-file=../envs/dev.tfvars
```

#### 3. Deploy Firewall Components
```bash
# Deploy firewalls (VM-Series or Cloud NGFW)
terraform apply -target=module.firewall_vmseries -var-file=../envs/dev.tfvars
# OR
terraform apply -target=module.firewall_cloudngfw -var-file=../envs/dev.tfvars
```

#### 4. Deploy Observability
```bash
# Deploy monitoring and logging
terraform apply -target=module.observability -var-file=../envs/dev.tfvars
```

#### 5. Full Deployment
```bash
# Deploy everything
terraform apply -var-file=../envs/dev.tfvars
```

### Phase 3: Using Make (Alternative)

```bash
# Using Makefile for simplified deployment
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

## Validation

### Automated Validation

#### 1. Health Checks
```bash
# Run health check script
./validation/health-check.sh

# Expected output:
# ✓ Inspection VPC is healthy
# ✓ Transit Gateway is healthy
# ✓ Gateway Load Balancer is healthy
# ✓ Found 2 running VM-Series instances
# ✓ Found 2 GWLB VPC endpoints
```

#### 2. Routing Validation
```bash
# Run routing check script
./validation/routing-check.sh

# Verify route symmetry
aws ec2 describe-route-tables --route-table-ids $SPOKE_RT_ID
```

#### 3. Terraform Validation
```bash
# Validate Terraform configuration
terraform validate

# Check formatting
terraform fmt -check

# Run all validations
make validate-all ENV=dev
```

### Manual Validation Steps

#### 1. Verify VPC Endpoints
```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=*gwlb*" \
  --query 'VpcEndpoints[*].{ID:VpcEndpointId,State:State,Type:VpcEndpointType}'

# Expected: State = "available"
```

#### 2. Verify GWLB Health
```bash
# Check GWLB target health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --query 'TargetHealthDescriptions[*].{ID:Target.Id,State:TargetHealth.State}'

# Expected: State = "healthy"
```

#### 3. Verify Firewall Registration
```bash
# For VM-Series, check Panorama registration
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=vmseries" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,IP:PrivateIpAddress}'
```

#### 4. Test Traffic Flow
```bash
# Test north-south traffic (from spoke instance)
ssh ec2-user@spoke-instance
curl -v https://www.google.com

# Test east-west traffic (between spoke instances)
ping 10.2.1.10  # From spoke-1 to spoke-2
```

### Monitoring Validation

#### 1. CloudWatch Metrics
```bash
# Check GWLB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/GatewayELB \
  --metric-name ActiveFlowCount \
  --start-time 2023-12-01T00:00:00Z \
  --end-time 2023-12-02T00:00:00Z \
  --period 300 \
  --statistics Maximum \
  --dimensions Name=LoadBalancer,Value=$GWLB_ARN
```

#### 2. Flow Logs Verification
```bash
# Check flow logs in S3
aws s3 ls s3://inspection-flow-logs/vpc-flow-logs/ --recursive

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/vpc/flow-logs
```

## Post-Deployment

### Step 1: Configure Panorama (VM-Series Only)

#### 1. Add Firewall to Panorama
```bash
# Panorama CLI commands
configure
set device-group aws-dg
set template aws-template
commit
```

#### 2. Push Policies
```bash
# Push security policies
set device-group aws-dg push all
```

#### 3. Verify Registration
```bash
# Check firewall status in Panorama
show devices connected
```

### Step 2: Configure Cloud NGFW (Cloud NGFW Only)

#### 1. Create Rule Stack
```bash
# Via AWS Console or CLI
aws cloudngfw create-rule-group \
  --rule-group-name inspection-rules \
  --rule-stack-name inspection-rule-stack
```

#### 2. Associate with VPC Endpoints
```bash
# Associate rulestack with GWLB endpoints
aws cloudngfw associate-rule-stack \
  --rule-stack-name inspection-rule-stack \
  --vpc-endpoint-ids $ENDPOINT_IDS
```

### Step 3: Update Application Route Tables

#### 1. Add Routes to GWLB Endpoints
```bash
# For each spoke VPC route table
aws ec2 create-route \
  --route-table-id $SPOKE_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --vpc-endpoint-id $GWLB_ENDPOINT_ID
```

#### 2. Add Routes for Inter-VPC Traffic
```bash
# Add routes to other spoke VPCs
aws ec2 create-route \
  --route-table-id $SPOKE_RT_ID \
  --destination-cidr-block 10.2.0.0/16 \
  --vpc-endpoint-id $GWLB_ENDPOINT_ID
```

### Step 4: Security Testing

#### 1. Test Security Policies
```bash
# Test allowed traffic
curl https://allowed-domain.com

# Test blocked traffic
curl https://blocked-domain.com  # Should be blocked
```

#### 2. Verify Threat Prevention
```bash
# Generate test traffic with known threats
# Monitor firewall logs for detection
```

### Step 5: Documentation Updates

#### 1. Update Network Diagrams
- Add new VPCs and subnets
- Update IP address assignments
- Document security group changes

#### 2. Update Runbooks
- Add new monitoring procedures
- Update incident response procedures
- Document firewall policy changes

## Maintenance

### Regular Tasks

#### Daily
```bash
# Check system health
make health-check

# Monitor key metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=vmseries-asg
```

#### Weekly
```bash
# Review CloudWatch alarms
aws cloudwatch describe-alarms --state-value ALARM

# Check flow log delivery
aws s3 ls s3://inspection-flow-logs/ --recursive | tail -10

# Update AMI versions (if available)
terraform plan -var-file=../envs/prod.tfvars | grep "aws_ami"
```

#### Monthly
```bash
# Security patching
aws ssm send-command \
  --document-name AWS-RunPatchBaseline \
  --targets "tag:Environment=inspection"

# Cost optimization review
aws ce get-cost-and-usage \
  --time-period Start=2023-11-01,End=2023-12-01 \
  --granularity MONTHLY \
  --metrics "BlendedCost"
```

### Updates and Upgrades

#### VM-Series Version Updates
```bash
# Update VM-Series version
terraform plan -var-file=../envs/prod.tfvars \
  -var="vmseries_version=10.2.1"

terraform apply -var-file=../envs/prod.tfvars \
  -var="vmseries_version=10.2.1"
```

#### Cloud NGFW Updates
```bash
# Update rulestack rules
aws cloudngfw update-rule-group \
  --rule-group-name inspection-rules \
  --rule-stack-name inspection-rule-stack \
  --rules $UPDATED_RULES
```

### Backup and Recovery

#### Configuration Backup
```bash
# Backup Terraform state
aws s3 cp s3://inspection-state/terraform.tfstate ./backups/

# Backup Panorama configuration
# Use Panorama backup features
```

#### Disaster Recovery Testing
```bash
# Test failover procedures
# Validate backup restoration
# Test cross-region recovery
```

## Troubleshooting Common Issues

### Deployment Issues

#### Terraform State Lock
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID

# Check lock status
aws dynamodb get-item \
  --table-name inspection-state-lock \
  --key '{"LockID":{"S":"terraform.tfstate"}}'
```

#### Resource Dependencies
```bash
# Deploy in correct order
terraform apply -target=module.network
terraform apply -target=module.inspection
terraform apply -target=module.firewall_vmseries
```

### Runtime Issues

#### High Latency
1. Check GWLB target health
2. Verify instance types and sizing
3. Review CloudWatch metrics
4. Consider cross-zone load balancing

#### Traffic Drops
1. Check security group rules
2. Verify route table configurations
3. Review firewall policies
4. Check VPC endpoint status

#### Auto-scaling Issues
1. Verify CloudWatch alarms
2. Check scaling policies
3. Review instance health checks
4. Validate IAM permissions

This deployment guide provides comprehensive instructions for successfully deploying and maintaining the AWS centralized traffic inspection architecture. For additional support, refer to the troubleshooting guide or open an issue in the repository.