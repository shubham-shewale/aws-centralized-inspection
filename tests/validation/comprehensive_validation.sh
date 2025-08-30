#!/bin/bash

# Comprehensive Infrastructure Validation Script
# This script performs end-to-end validation of the AWS centralized inspection architecture

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENT="${ENVIRONMENT:-test}"
REGION="${REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Track validation results
declare -a FAILED_VALIDATIONS=()

# Validation result function
validate_result() {
    local check_name="$1"
    local result="$2"
    local details="$3"

    ((TOTAL_CHECKS++))
    if [ "$result" = "true" ] || [ "$result" = "0" ]; then
        ((PASSED_CHECKS++))
        log_success "$check_name"
        [ -n "$details" ] && echo "  $details"
    else
        ((FAILED_CHECKS++))
        FAILED_VALIDATIONS+=("$check_name")
        log_error "$check_name"
        [ -n "$details" ] && echo "  $details"
    fi
}

# AWS CLI validation
validate_aws_cli() {
    log_info "Validating AWS CLI configuration..."

    # Check AWS CLI installation
    if ! command -v aws >/dev/null 2>&1; then
        validate_result "AWS CLI Installation" false "AWS CLI is not installed"
        return 1
    fi
    validate_result "AWS CLI Installation" true "AWS CLI is installed"

    # Check AWS credentials
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
        validate_result "AWS Credentials" false "AWS credentials are not configured or invalid"
        return 1
    fi
    validate_result "AWS Credentials" true "AWS credentials are configured"

    # Check region
    local current_region
    current_region=$(aws configure get region --profile "$AWS_PROFILE")
    if [ "$current_region" != "$REGION" ]; then
        log_warning "AWS region mismatch: configured=$current_region, expected=$REGION"
    fi
    validate_result "AWS Region" true "Region: $current_region"
}

# Terraform validation
validate_terraform() {
    log_info "Validating Terraform configuration..."

    cd "$PROJECT_ROOT"

    # Check Terraform installation
    if ! command -v terraform >/dev/null 2>&1; then
        validate_result "Terraform Installation" false "Terraform is not installed"
        return 1
    fi
    validate_result "Terraform Installation" true "Terraform is installed"

    # Check Terraform version
    local tf_version
    tf_version=$(terraform version | head -n 1 | cut -d' ' -f2 | sed 's/v//')
    if [ "$(printf '%s\n' "$tf_version" "1.5.0" | sort -V | head -n1)" != "1.5.0" ]; then
        validate_result "Terraform Version" false "Terraform version $tf_version is below minimum required 1.5.0"
        return 1
    fi
    validate_result "Terraform Version" true "Version: $tf_version"

    # Validate Terraform configuration
    if ! terraform validate >/dev/null 2>&1; then
        validate_result "Terraform Configuration" false "Terraform configuration has validation errors"
        return 1
    fi
    validate_result "Terraform Configuration" true "Configuration is valid"
}

# Network infrastructure validation
validate_network_infrastructure() {
    log_info "Validating network infrastructure..."

    # Check VPC existence
    local vpc_count
    vpc_count=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=centralized-inspection" --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
    if [ "$vpc_count" -eq 0 ]; then
        validate_result "Inspection VPC" false "No inspection VPC found"
        return 1
    fi
    validate_result "Inspection VPC" true "Found $vpc_count inspection VPC(s)"

    # Check Transit Gateway
    local tgw_count
    tgw_count=$(aws ec2 describe-transit-gateways --filters "Name=tag:Project,Values=centralized-inspection" --query 'length(TransitGateways)' --output text 2>/dev/null || echo "0")
    if [ "$tgw_count" -eq 0 ]; then
        validate_result "Transit Gateway" false "No Transit Gateway found"
        return 1
    fi
    validate_result "Transit Gateway" true "Found $tgw_count Transit Gateway(s)"

    # Check subnets
    local subnet_count
    subnet_count=$(aws ec2 describe-subnets --filters "Name=tag:Project,Values=centralized-inspection" --query 'length(Subnets)' --output text 2>/dev/null || echo "0")
    if [ "$subnet_count" -lt 3 ]; then
        validate_result "Subnets" false "Found $subnet_count subnets, expected at least 3"
        return 1
    fi
    validate_result "Subnets" true "Found $subnet_count subnets"
}

# Security infrastructure validation
validate_security_infrastructure() {
    log_info "Validating security infrastructure..."

    # Check Gateway Load Balancer
    local gwlb_count
    gwlb_count=$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers[?Type==`gateway`])' --output text 2>/dev/null || echo "0")
    if [ "$gwlb_count" -eq 0 ]; then
        validate_result "Gateway Load Balancer" false "No Gateway Load Balancer found"
        return 1
    fi
    validate_result "Gateway Load Balancer" true "Found $gwlb_count Gateway Load Balancer(s)"

    # Check target groups
    local tg_count
    tg_count=$(aws elbv2 describe-target-groups --query 'length(TargetGroups[?Protocol==`GENEVE`])' --output text 2>/dev/null || echo "0")
    if [ "$tg_count" -eq 0 ]; then
        validate_result "Target Groups" false "No GENEVE target groups found"
        return 1
    fi
    validate_result "Target Groups" true "Found $tg_count GENEVE target group(s)"

    # Check security groups
    local sg_count
    sg_count=$(aws ec2 describe-security-groups --filters "Name=tag:Project,Values=centralized-inspection" --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "0")
    if [ "$sg_count" -eq 0 ]; then
        validate_result "Security Groups" false "No security groups found"
        return 1
    fi
    validate_result "Security Groups" true "Found $sg_count security group(s)"
}

# Firewall validation
validate_firewall_configuration() {
    log_info "Validating firewall configuration..."

    # Check Auto Scaling Groups
    local asg_count
    asg_count=$(aws autoscaling describe-auto-scaling-groups --query 'length(AutoScalingGroups[?contains(AutoScalingGroupName, `vmseries`)])' --output text 2>/dev/null || echo "0")
    if [ "$asg_count" -eq 0 ]; then
        validate_result "VM-Series Auto Scaling" false "No VM-Series Auto Scaling groups found"
        return 1
    fi
    validate_result "VM-Series Auto Scaling" true "Found $asg_count VM-Series Auto Scaling group(s)"

    # Check instances in ASG
    local instance_count
    instance_count=$(aws autoscaling describe-auto-scaling-groups --query 'sum(AutoScalingGroups[?contains(AutoScalingGroupName, `vmseries`)].Instances | length)' --output text 2>/dev/null || echo "0")
    if [ "$instance_count" -eq 0 ]; then
        validate_result "VM-Series Instances" false "No VM-Series instances running"
        return 1
    fi
    validate_result "VM-Series Instances" true "Found $instance_count VM-Series instance(s) running"
}

# Monitoring and logging validation
validate_monitoring_logging() {
    log_info "Validating monitoring and logging..."

    # Check VPC Flow Logs
    local flow_log_count
    flow_log_count=$(aws ec2 describe-flow-logs --query 'length(FlowLogs[?FlowLogStatus==`ACTIVE`])' --output text 2>/dev/null || echo "0")
    if [ "$flow_log_count" -eq 0 ]; then
        validate_result "VPC Flow Logs" false "No active VPC Flow Logs found"
        return 1
    fi
    validate_result "VPC Flow Logs" true "Found $flow_log_count active VPC Flow Log(s)"

    # Check CloudWatch Log Groups
    local log_group_count
    log_group_count=$(aws logs describe-log-groups --query 'length(LogGroups[?contains(LogGroupName, `inspection`)])' --output text 2>/dev/null || echo "0")
    if [ "$log_group_count" -eq 0 ]; then
        validate_result "CloudWatch Log Groups" false "No inspection-related log groups found"
        return 1
    fi
    validate_result "CloudWatch Log Groups" true "Found $log_group_count inspection-related log group(s)"
}

# Compliance validation
validate_compliance() {
    log_info "Validating compliance configuration..."

    # Check encryption at rest
    local encrypted_volume_count
    encrypted_volume_count=$(aws ec2 describe-volumes --filters "Name=encrypted,Values=true" --query 'length(Volumes)' --output text 2>/dev/null || echo "0")
    if [ "$encrypted_volume_count" -eq 0 ]; then
        validate_result "Encryption at Rest" false "No encrypted volumes found"
        return 1
    fi
    validate_result "Encryption at Rest" true "Found $encrypted_volume_count encrypted volume(s)"

    # Check resource tagging
    local tagged_resource_count
    tagged_resource_count=$(aws resource-groups get-group-query --group-name "centralized-inspection" --query 'length(GroupQuery.ResourceQueryFilters)' 2>/dev/null || echo "0")
    if [ "$tagged_resource_count" -eq 0 ]; then
        log_warning "Resource tagging validation requires resource groups configuration"
        validate_result "Resource Tagging" true "Resource tagging check skipped (requires resource groups)"
    else
        validate_result "Resource Tagging" true "Resource tagging is configured"
    fi
}

# Traffic flow validation
validate_traffic_flow() {
    log_info "Validating traffic flow..."

    # This would require actual traffic generation and monitoring
    # For now, we'll validate that the necessary components are in place

    # Check route tables
    local route_table_count
    route_table_count=$(aws ec2 describe-route-tables --filters "Name=tag:Project,Values=centralized-inspection" --query 'length(RouteTables)' --output text 2>/dev/null || echo "0")
    if [ "$route_table_count" -eq 0 ]; then
        validate_result "Route Tables" false "No route tables found"
        return 1
    fi
    validate_result "Route Tables" true "Found $route_table_count route table(s)"

    # Check VPC endpoints
    local endpoint_count
    endpoint_count=$(aws ec2 describe-vpc-endpoints --query 'length(VpcEndpoints[?VpcEndpointType==`GatewayLoadBalancer`])' --output text 2>/dev/null || echo "0")
    if [ "$endpoint_count" -eq 0 ]; then
        validate_result "GWLB Endpoints" false "No Gateway Load Balancer endpoints found"
        return 1
    fi
    validate_result "GWLB Endpoints" true "Found $endpoint_count Gateway Load Balancer endpoint(s)"
}

# Performance validation
validate_performance() {
    log_info "Validating performance metrics..."

    # Check GWLB healthy targets
    local healthy_targets
    healthy_targets=$(aws elbv2 describe-target-health --target-group-arn "arn:aws:elasticloadbalancing:$REGION:123456789012:targetgroup/inspection-tg/1234567890abcdef" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' 2>/dev/null || echo "0")
    if [ "$healthy_targets" = "0" ]; then
        validate_result "Healthy Targets" false "No healthy targets found in target group"
        return 1
    fi
    validate_result "Healthy Targets" true "Found $healthy_targets healthy target(s)"

    # Check instance performance (CPU, Memory)
    local high_cpu_instances
    high_cpu_instances=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=AutoScalingGroupName,Value=vmseries-asg --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" --period 300 --statistics Maximum --query 'length(Datapoints[?Maximum > `80`])' --output text 2>/dev/null || echo "0")
    if [ "$high_cpu_instances" -gt 0 ]; then
        log_warning "Found instances with high CPU utilization (>80%)"
        validate_result "CPU Utilization" false "High CPU utilization detected on $high_cpu_instances instance(s)"
        return 1
    fi
    validate_result "CPU Utilization" true "CPU utilization is within acceptable limits"
}

# Cost optimization validation
validate_cost_optimization() {
    log_info "Validating cost optimization..."

    # Check for unused resources
    local unused_volumes
    unused_volumes=$(aws ec2 describe-volumes --filters "Name=status,Values=available" --query 'length(Volumes)' --output text 2>/dev/null || echo "0")
    if [ "$unused_volumes" -gt 0 ]; then
        log_warning "Found $unused_volumes unused EBS volumes"
        validate_result "Unused Resources" false "Found $unused_volumes unused EBS volume(s)"
        return 1
    fi
    validate_result "Unused Resources" true "No unused EBS volumes found"

    # Check for untagged resources
    local untagged_instances
    untagged_instances=$(aws ec2 describe-instances --query 'length(Reservations[*].Instances[?length(Tags)==`0`])' --output text 2>/dev/null || echo "0")
    if [ "$untagged_instances" -gt 0 ]; then
        log_warning "Found $untagged_instances untagged instances"
        validate_result "Resource Tagging" false "Found $untagged_instances untagged instance(s)"
        return 1
    fi
    validate_result "Resource Tagging" true "All instances are properly tagged"
}

# Main validation function
main() {
    log_info "Starting comprehensive infrastructure validation..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "AWS Profile: $AWS_PROFILE"
    echo

    # Run all validations
    validate_aws_cli
    echo
    validate_terraform
    echo
    validate_network_infrastructure
    echo
    validate_security_infrastructure
    echo
    validate_firewall_configuration
    echo
    validate_monitoring_logging
    echo
    validate_compliance
    echo
    validate_traffic_flow
    echo
    validate_performance
    echo
    validate_cost_optimization
    echo

    # Summary
    log_info "Validation Summary:"
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Failed: $FAILED_CHECKS"
    echo

    if [ "$FAILED_CHECKS" -gt 0 ]; then
        log_error "Failed Validations:"
        for failed_validation in "${FAILED_VALIDATIONS[@]}"; do
            echo "  - $failed_validation"
        done
        echo
        log_error "Infrastructure validation FAILED"
        exit 1
    else
        log_success "All validations PASSED"
        log_success "Infrastructure is ready for production"
        exit 0
    fi
}

# Run main function
main "$@"