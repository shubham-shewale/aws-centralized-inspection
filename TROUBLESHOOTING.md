# Troubleshooting Guide

This comprehensive troubleshooting guide provides solutions for common issues encountered during deployment and operation of the AWS centralized traffic inspection architecture.

## Table of Contents

1. [Quick Diagnosis](#quick-diagnosis)
2. [Deployment Issues](#deployment-issues)
3. [Runtime Issues](#runtime-issues)
4. [Performance Issues](#performance-issues)
5. [Connectivity Issues](#connectivity-issues)
6. [Security Issues](#security-issues)
7. [Monitoring Issues](#monitoring-issues)
8. [Advanced Diagnostics](#advanced-diagnostics)

## Quick Diagnosis

### System Health Check

Run the automated health check script:

```bash
# Comprehensive health check
./validation/health-check.sh

# Expected healthy output:
# ✓ Inspection VPC is healthy
# ✓ Transit Gateway is healthy
# ✓ Gateway Load Balancer is healthy
# ✓ Found 2 running VM-Series instances
# ✓ Found 2 GWLB VPC endpoints
```

### Quick Status Commands

```bash
# Check all components status
aws ec2 describe-vpcs --vpc-ids $INSPECTION_VPC_ID --query 'Vpcs[0].State'
aws ec2 describe-transit-gateways --transit-gateway-ids $TGW_ID --query 'TransitGateways[0].State'
aws elbv2 describe-load-balancers --names inspection-gwlb --query 'LoadBalancers[0].State.Code'
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names vmseries-asg --query 'AutoScalingGroups[0].Instances'
```

## Deployment Issues

### Terraform State Issues

#### State Lock Conflicts
**Symptoms:**
- `Error: Error acquiring the state lock`
- Deployment hangs during `terraform apply`

**Solutions:**
```bash
# Check current lock status
aws dynamodb get-item \
  --table-name inspection-state-lock \
  --key '{"LockID":{"S":"aws-centralized-inspection/live/terraform.tfstate"}}'

# Force unlock (use with caution)
terraform force-unlock LOCK_ID

# Clean up stale locks
aws dynamodb delete-item \
  --table-name inspection-state-lock \
  --key '{"LockID":{"S":"aws-centralized-inspection/live/terraform.tfstate"}}'
```

#### State File Corruption
**Symptoms:**
- `Error: state snapshot was created by Terraform vx.x.x`
- Inconsistent state between local and remote

**Solutions:**
```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Refresh state from remote
terraform refresh

# If refresh fails, restore from backup
cp terraform.tfstate.backup terraform.tfstate
```

### Resource Dependency Issues

#### Circular Dependencies
**Symptoms:**
- `Error: Cycle: resource A -> resource B -> resource A`

**Solutions:**
```bash
# Use depends_on to break cycles
resource "aws_route" "example" {
  depends_on = [aws_vpc_endpoint.example]
  # ... other configuration
}

# Or restructure resource creation order
terraform apply -target=module.network
terraform apply -target=module.inspection
terraform apply -target=module.firewall_vmseries
```

#### Resource Creation Timeouts
**Symptoms:**
- `Error: timeout while waiting for resource to be created`

**Solutions:**
```bash
# Increase timeout values
resource "aws_instance" "vmseries" {
  timeouts {
    create = "20m"
    update = "10m"
    delete = "20m"
  }
}

# Check AWS service limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

### IAM Permission Issues

#### Insufficient Permissions
**Symptoms:**
- `Error: AccessDenied`
- `Error: UnauthorizedOperation`

**Solutions:**
```bash
# Verify current user permissions
aws sts get-caller-identity

# Test specific permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/terraform-user \
  --action-names ec2:DescribeVpcs iam:CreateRole \
  --resource-arns "*"

# Update IAM policy
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
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Runtime Issues

### GWLB Endpoint Issues

#### Endpoint Creation Failures
**Symptoms:**
- VPC endpoint stuck in `pending` state
- `Error: VPC endpoint service not found`

**Solutions:**
```bash
# Check endpoint service status
aws ec2 describe-vpc-endpoint-services \
  --service-names com.amazonaws.vpce.us-east-1.vpce-svc-12345

# Verify service permissions
aws ec2 describe-vpc-endpoint-service-permissions \
  --service-id vpce-svc-12345

# Recreate endpoint service
terraform taint aws_vpc_endpoint_service.gwlb
terraform apply -target=aws_vpc_endpoint_service.gwlb
```

#### Endpoint Connection Issues
**Symptoms:**
- Traffic not flowing through GWLB
- Endpoint shows as `rejected`

**Solutions:**
```bash
# Check endpoint connection status
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids vpce-12345 \
  --query 'VpcEndpoints[0].VpcEndpointConnections'

# Verify security groups
aws ec2 describe-security-groups \
  --group-ids sg-12345 \
  --query 'SecurityGroups[0].IpPermissions'

# Check route table associations
aws ec2 describe-route-tables \
  --route-table-ids rtb-12345 \
  --query 'RouteTables[0].Routes'
```

### VM-Series Bootstrap Issues

#### Panorama Connection Failures
**Symptoms:**
- Firewall shows as `unregistered` in Panorama
- Bootstrap logs show connection errors

**Solutions:**
```bash
# Test Panorama connectivity
telnet panorama.example.com 3978

# Check bootstrap configuration
aws s3 ls s3://vmseries-bootstrap/

# Verify bootstrap template
cat > bootstrap.xml << EOF
<vm-series>
  <type>
    <dhcp-client>
      <send-hostname>yes</send-hostname>
      <send-client-id>yes</send-client-id>
      <accept-dhcp-hostname>no</accept-dhcp-hostname>
      <accept-dhcp-domain>no</accept-dhcp-domain>
    </dhcp-client>
  </type>
  <panorama-server>panorama.example.com</panorama-server>
  <auth-key>your-auth-key</auth-key>
  <dgname>aws-dg</dgname>
  <tplname>aws-template</tplname>
</vm-series>
EOF

# Update bootstrap and redeploy
terraform apply -target=module.firewall_vmseries
```

#### License Activation Issues
**Symptoms:**
- Firewall shows as `unlicensed`
- Features not working

**Solutions:**
```bash
# Check license status
show system info | match "serial"

# Retrieve auth codes from Panorama
# Verify auth code validity
# Redeploy with correct auth codes
```

### Auto-scaling Issues

#### Scaling Events Not Triggering
**Symptoms:**
- CPU high but no scale-out
- Manual scaling works but automatic doesn't

**Solutions:**
```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-names vmseries-cpu-high \
  --query 'MetricAlarms[0].StateValue'

# Verify scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name vmseries-asg

# Test alarm manually
aws cloudwatch set-alarm-state \
  --alarm-name vmseries-cpu-high \
  --state-value ALARM \
  --state-reason "Testing alarm"
```

#### Instance Health Check Failures
**Symptoms:**
- Instances terminated immediately after launch
- Health checks failing

**Solutions:**
```bash
# Check instance status
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=vmseries-asg" \
  --query 'Reservations[*].Instances[*].State'

# Verify health check configuration
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names vmseries-asg \
  --query 'AutoScalingGroups[0].HealthCheckType'

# Check system logs
aws logs get-log-events \
  --log-group-name /aws/vmseries/bootstrap \
  --log-stream-name i-1234567890abcdef
```

#### Automated Remediation Issues
**Symptoms:**
- Security events not triggering remediation
- Lambda function errors in logs
- SNS alerts not being sent

**Solutions:**
```bash
# Check Lambda function status
aws lambda get-function --function-name inspection-security-automation

# Review Lambda execution logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/inspection-security-automation \
  --start-time $(date -d '1 hour ago' +%s)

# Verify CloudWatch Events rules
aws events list-rules --name-prefix inspection-security

# Check SNS topic permissions
aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN

# Test remediation manually
aws lambda invoke \
  --function-name inspection-security-automation \
  --payload '{"test": "security-event"}' \
  output.json
```

#### Remediation Scope Configuration Issues
**Symptoms:**
- Remediation actions not executing as expected
- Overly aggressive or insufficient remediation

**Solutions:**
```bash
# Check remediation configuration
terraform show | grep remediation_scope

# Verify IAM permissions for remediation actions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/lambda-execution-role \
  --action-names ec2:RevokeSecurityGroupIngress ec2:ModifyInstanceAttribute

# Review CloudWatch alarms configuration
aws cloudwatch describe-alarms --alarm-name-prefix inspection

# Test remediation scope settings
terraform plan -var="enable_auto_remediation=false"
```

## Performance Issues

### High Latency

#### Network Latency
**Symptoms:**
- Traffic delays through inspection
- Application timeouts

**Solutions:**
```bash
# Check GWLB latency metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/GatewayELB \
  --metric-name TargetResponseTime \
  --start-time 2023-12-01T00:00:00Z \
  --end-time 2023-12-02T00:00:00Z \
  --period 300 \
  --statistics Average

# Enable cross-zone load balancing
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn $GWLB_ARN \
  --attributes Key=load_balancing.cross_zone.enabled,Value=true

# Check instance performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=vmseries-asg
```

#### Application Latency
**Symptoms:**
- Slow application response times
- Database query timeouts

**Solutions:**
```bash
# Review firewall policies for optimization
# Check for unnecessary deep inspection
# Consider fast-path rules for trusted traffic

# Monitor session table utilization
show session info
```

### Throughput Issues

#### Low Throughput
**Symptoms:**
- Traffic shaping occurring
- Bandwidth limitations

**Solutions:**
```bash
# Scale up instance types
terraform apply -var="vmseries_instance_type=m5.2xlarge"

# Enable session acceleration
set deviceconfig system session-acceleration enable

# Check interface statistics
show interface all
```

#### Traffic Drops
**Symptoms:**
- Packet loss through inspection
- Intermittent connectivity

**Solutions:**
```bash
# Check GWLB target health
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN

# Verify MTU settings
# Check for fragmentation issues
# Review QoS policies
```

### Resource Exhaustion

#### CPU/Memory Issues
**Symptoms:**
- High CPU utilization
- Memory pressure
- System slowdowns

**Solutions:**
```bash
# Monitor resource usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=vmseries-asg

# Scale horizontally
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name vmseries-asg \
  --min-size 4 \
  --max-size 8

# Optimize policies
# Reduce logging verbosity
# Enable hardware acceleration
```

## Connectivity Issues

### North-South Traffic Issues

#### Internet Access Problems
**Symptoms:**
- Cannot reach internet from spoke VPCs
- DNS resolution failures

**Solutions:**
```bash
# Check route tables
aws ec2 describe-route-tables \
  --route-table-ids $SPOKE_RT_ID \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'

# Verify IGW attachment
aws ec2 describe-internet-gateways \
  --internet-gateway-ids $IGW_ID

# Check NAT gateway status
aws ec2 describe-nat-gateways \
  --nat-gateway-ids $NAT_ID
```

#### DNS Issues
**Symptoms:**
- Name resolution failures
- Slow DNS responses

**Solutions:**
```bash
# Check DHCP options
aws ec2 describe-dhcp-options \
  --dhcp-options-ids $DHCP_ID

# Verify DNS server configuration
# Check firewall DNS proxy settings
# Test DNS resolution from instances
```

### East-West Traffic Issues

#### Inter-VPC Connectivity Problems
**Symptoms:**
- Cannot reach applications in other VPCs
- Asymmetric routing

**Solutions:**
```bash
# Check TGW route tables
aws ec2 describe-transit-gateway-route-tables \
  --transit-gateway-route-table-ids $TGW_RT_ID

# Verify TGW attachments
aws ec2 describe-transit-gateway-attachments \
  --transit-gateway-id $TGW_ID

# Check spoke VPC routes
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$SPOKE_VPC_ID"
```

#### Routing Asymmetry
**Symptoms:**
- One-way traffic flows
- Session establishment failures

**Solutions:**
```bash
# Validate return path routing
# Check for route table inconsistencies
# Verify GWLB endpoint configurations
# Test with symmetric routing validation script
./validation/routing-check.sh
```

## Security Issues

### Policy Enforcement Issues

#### Traffic Not Being Inspected
**Symptoms:**
- Traffic bypassing firewall
- Security violations not blocked

**Solutions:**
```bash
# Check route table configurations
aws ec2 describe-route-tables --route-table-ids $RT_ID

# Verify GWLB endpoint associations
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $ENDPOINT_ID

# Check firewall policy order
show security policy

# Verify security group rules (enhanced security)
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions'
```

#### False Positives/Negatives
**Symptoms:**
- Legitimate traffic blocked
- Malicious traffic allowed

**Solutions:**
```bash
# Review security policies
show security policy | match "action deny"

# Check threat signatures
show threat vault statistics

# Adjust policy rules
# Update threat prevention profiles

# Validate security rules configuration
terraform validate
terraform plan -var-file=envs/prod.tfvars
```

### Encryption and Key Management Issues

#### KMS Key Access Problems
**Symptoms:**
- EBS encryption failures
- S3 bucket access denied
- Terraform state encryption errors

**Solutions:**
```bash
# Check KMS key permissions
aws kms describe-key --key-id $KMS_KEY_ID

# Verify IAM permissions for KMS
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/terraform-role \
  --action-names kms:CreateGrant kms:DescribeKey kms:Decrypt kms:GenerateDataKey \
  --resource-arns arn:aws:kms:us-east-1:123456789012:key/*

# Check key rotation status
aws kms get-key-rotation-status --key-id $KMS_KEY_ID
```

#### Certificate Validation Issues
**Symptoms:**
- SSL/TLS handshake failures
- Certificate validation errors

**Solutions:**
```bash
# Check ACM certificate status
aws acm describe-certificate --certificate-arn $CERT_ARN

# Verify certificate chain
openssl s_client -connect example.com:443 -servername example.com

# Check CloudFront distribution configuration
aws cloudfront get-distribution --id $DISTRIBUTION_ID
```

### Access Control Issues

#### IAM Permission Denied
**Symptoms:**
- Terraform apply fails with AccessDenied
- Resources cannot be created or modified

**Solutions:**
```bash
# Check current IAM permissions
aws sts get-caller-identity

# Simulate policy evaluation
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/terraform-role \
  --action-names ec2:CreateVpc iam:CreateRole

# Verify MFA requirements (if enabled)
aws sts get-session-token --serial-number arn:aws:iam::123456789012:mfa/user --token-code 123456
```

#### Cross-Account Access Failures
**Symptoms:**
- Assume role operations failing
- Cross-account resource access denied

**Solutions:**
```bash
# Check trust relationship
aws iam get-role --role-name cross-account-role --query 'Role.AssumeRolePolicyDocument'

# Verify external ID (if used)
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/cross-account-role \
  --role-session-name test-session \
  --external-id your-external-id

# Check account limits
aws service-quotas get-service-quota --service-code iam --quota-code L-0DA4ABF3
```

### Authentication Issues

#### Panorama Authentication Failures
**Symptoms:**
- Cannot authenticate to Panorama
- Policy push failures

**Solutions:**
```bash
# Verify credentials
# Check certificate validity
# Test network connectivity
telnet panorama.example.com 3978

# Reset authentication
# Update bootstrap configuration
```

## Monitoring Issues

### Flow Log Issues

#### Logs Not Appearing
**Symptoms:**
- No flow logs in S3/CloudWatch
- Empty log files

**Solutions:**
```bash
# Check flow log status
aws ec2 describe-flow-logs --flow-log-ids $FLOW_LOG_ID

# Verify IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/FlowLogRole \
  --action-names logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents

# Check S3 bucket permissions
aws s3api get-bucket-policy --bucket $LOG_BUCKET
```

#### Log Format Issues
**Symptoms:**
- Malformed log entries
- Missing fields

**Solutions:**
```bash
# Verify log format configuration
aws ec2 describe-flow-logs \
  --flow-log-ids $FLOW_LOG_ID \
  --query 'FlowLogs[0].LogFormat'

# Check log destination
# Validate log parsing tools
```

### CloudWatch Issues

#### Metrics Not Updating
**Symptoms:**
- Stale metric data
- Missing metrics

**Solutions:**
```bash
# Check metric filters
aws logs describe-metric-filters \
  --log-group-name /aws/vpc/flow-logs/inspection

# Verify IAM permissions for CloudWatch
# Check metric namespace
aws cloudwatch list-metrics --namespace AWS/EC2
```

#### Alarms Not Triggering
**Symptoms:**
- No alarm notifications
- Alarms stuck in OK state

**Solutions:**
```bash
# Check alarm configuration
aws cloudwatch describe-alarms --alarm-names $ALARM_NAME

# Test alarm manually
aws cloudwatch set-alarm-state \
  --alarm-name $ALARM_NAME \
  --state-value ALARM \
  --state-reason "Testing"

# Verify SNS topic permissions
aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC
```

## Advanced Diagnostics

### Packet Capture

#### VM-Series Packet Capture
```bash
# Enable packet capture
debug dataplane packet-diag set capture on

# Set capture filter
debug dataplane packet-diag set filter on
debug dataplane packet-diag set filter match source 10.1.1.10

# Start capture
debug dataplane packet-diag set capture stage firewall

# View captures
show dataplane packet-diag capture
```

#### AWS VPC Traffic Mirroring
```bash
# Create traffic mirror session
aws ec2 create-traffic-mirror-session \
  --network-interface-id $ENI_ID \
  --traffic-mirror-target-id $TARGET_ID \
  --traffic-mirror-filter-id $FILTER_ID \
  --session-number 1

# Monitor mirrored traffic
# Use third-party tools for analysis
```

### Log Analysis

#### Firewall Log Analysis
```bash
# Search for specific traffic
show log traffic direction equal both \
  source 10.1.1.10 \
  destination 10.2.1.10

# Check threat logs
show log threat direction equal both \
  threatid eq 12345

# Monitor system logs
show log system direction equal both \
  subtype eq general
```

#### CloudWatch Log Insights
```sql
# Query VPC flow logs
fields @timestamp, @message
| filter isIpv4
| filter dstPort = 80 or dstPort = 443
| stats count() by srcAddr, dstAddr
| sort @timestamp desc
| limit 100
```

### Performance Profiling

#### System Performance Analysis
```bash
# Check system resources
show system resources

# Monitor session table
show session info

# Check interface statistics
show interface ethernet1/1

# Review policy hit counts
show security policy hit-count
```

#### AWS Performance Analysis
```bash
# Check instance performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef

# Monitor network performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef
```

### Automated Diagnostics

#### Create Diagnostic Script
```bash
#!/bin/bash
# Comprehensive diagnostic script

echo "=== AWS Centralized Inspection Diagnostics ==="

# Check AWS resources
echo "Checking VPC status..."
aws ec2 describe-vpcs --vpc-ids $INSPECTION_VPC_ID

echo "Checking GWLB status..."
aws elbv2 describe-load-balancers --names inspection-gwlb

echo "Checking VM-Series instances..."
aws ec2 describe-instances --filters "Name=tag:Name,Values=vmseries"

# Check firewall status (if accessible)
echo "Checking firewall connectivity..."
# Add firewall-specific checks

echo "=== Diagnostics Complete ==="
```

### Escalation Procedures

#### When to Escalate
- Issues persisting after troubleshooting
- Performance degradation affecting production
- Security incidents or breaches
- Data loss or corruption

#### Escalation Steps
1. Gather all diagnostic information
2. Document steps taken and results
3. Contact appropriate support channels:
   - AWS Support for infrastructure issues
   - Palo Alto Networks Support for firewall issues
   - Internal DevOps/Security teams

#### Required Information for Escalation
- Terraform state files
- CloudWatch logs and metrics
- Firewall logs and configurations
- Network packet captures
- System resource utilization
- Timeline of events

This troubleshooting guide covers the most common issues and provides systematic approaches to diagnosis and resolution. For issues not covered here, consult the official documentation or open an issue in the repository.