#!/bin/bash

set -e

echo "Running health checks for AWS Centralized Inspection..."

# Enhanced health check script with better error handling and comprehensive validation
set -euo pipefail

# Load variables from environment or terraform output
# Set these variables before running the script or use terraform output
INSPECTION_VPC_ID=${INSPECTION_VPC_ID:-"$(terraform output -raw inspection_vpc_id 2>/dev/null || echo '')"}
TGW_ID=${TGW_ID:-"$(terraform output -raw transit_gateway_id 2>/dev/null || echo '')"}
GWLB_NAME=${GWLB_NAME:-"inspection-gwlb"}
INSTANCE_TAG=${INSTANCE_TAG:-"vmseries"}
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  local status=$1
  local message=$2
  case $status in
    "PASS")
      echo -e "${GREEN}✓${NC} $message"
      ;;
    "FAIL")
      echo -e "${RED}✗${NC} $message"
      ;;
    "WARN")
      echo -e "${YELLOW}⚠${NC} $message"
      ;;
    *)
      echo "$message"
      ;;
  esac
}

# Function to check resource state with better error handling
check_resource() {
  local resource_type=$1
  local check_command=$2
  local expected=$3
  local severity=${4:-"FAIL"}

  echo "Checking $resource_type..."
  if result=$(eval "$check_command" 2>/dev/null); then
    if echo "$result" | grep -q "$expected"; then
      print_status "PASS" "$resource_type is healthy"
      return 0
    else
      print_status "$severity" "$resource_type check failed (expected: $expected, got: $(echo $result | tr '\n' ' '))"
      return 1
    fi
  else
    print_status "$severity" "$resource_type check failed (command error)"
    return 1
  fi
}

# Function to check AWS resource existence and state
check_aws_resource() {
  local resource_type=$1
  local query=$2
  local expected=$3
  local severity=${4:-"FAIL"}

  echo "Checking $resource_type..."
  if result=$(aws $query --region $AWS_REGION 2>/dev/null); then
    if [ -n "$result" ] && echo "$result" | grep -q "$expected"; then
      print_status "PASS" "$resource_type exists and is healthy"
      return 0
    else
      print_status "$severity" "$resource_type not found or unhealthy"
      return 1
    fi
  else
    print_status "$severity" "$resource_type check failed (AWS CLI error)"
    return 1
  fi
}

# Initialize counters
CHECKS_TOTAL=0
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Function to track results
track_result() {
  local result=$1
  ((CHECKS_TOTAL++))
  case $result in
    0) ((CHECKS_PASSED++)) ;;
    1) ((CHECKS_FAILED++)) ;;
    2) ((CHECKS_WARNED++)) ;;
  esac
}

echo "=== AWS Centralized Inspection Health Check ==="
echo "Region: $AWS_REGION"
echo "Timestamp: $(date)"
echo

# Check Inspection VPC
if [ -n "$INSPECTION_VPC_ID" ]; then
  check_aws_resource "Inspection VPC" "ec2 describe-vpcs --vpc-ids $INSPECTION_VPC_ID --query 'Vpcs[0].State' --output text" "available"
  track_result $?
else
  print_status "WARN" "Inspection VPC ID not provided, skipping check"
fi

# Check Transit Gateway
if [ -n "$TGW_ID" ]; then
  check_aws_resource "Transit Gateway" "ec2 describe-transit-gateways --transit-gateway-ids $TGW_ID --query 'TransitGateways[0].State' --output text" "available"
  track_result $?
else
  print_status "WARN" "Transit Gateway ID not provided, skipping check"
fi

# Check Gateway Load Balancer
check_aws_resource "Gateway Load Balancer" "elbv2 describe-load-balancers --names $GWLB_NAME --query 'LoadBalancers[0].State.Code' --output text" "active" "WARN"
track_result $?

# Check VM-Series instances
echo "Checking VM-Series instances..."
if INSTANCE_COUNT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCE_TAG" "Name=instance-state-name,Values=running" --query 'Reservations | length(@)' --output text 2>/dev/null); then
  if [ "$INSTANCE_COUNT" -gt 0 ]; then
    print_status "PASS" "Found $INSTANCE_COUNT running VM-Series instances"
    track_result 0
  else
    print_status "FAIL" "No running VM-Series instances found"
    track_result 1
  fi
else
  print_status "WARN" "Unable to check VM-Series instances"
  track_result 2
fi

# Check VPC endpoints
echo "Checking VPC endpoints..."
if ENDPOINT_COUNT=$(aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=*gwlb*" --query 'VpcEndpoints | length(@)' --output text 2>/dev/null); then
  if [ "$ENDPOINT_COUNT" -gt 0 ]; then
    print_status "PASS" "Found $ENDPOINT_COUNT GWLB VPC endpoints"
    track_result 0
  else
    print_status "FAIL" "No GWLB VPC endpoints found"
    track_result 1
  fi
else
  print_status "WARN" "Unable to check VPC endpoints"
  track_result 2
fi

# Check S3 buckets for flow logs
echo "Checking S3 buckets..."
if aws s3 ls "s3://aws-centralized-inspection-logs-" 2>/dev/null | grep -q "aws-centralized-inspection-logs-"; then
  print_status "PASS" "Flow logs S3 bucket exists"
  track_result 0
else
  print_status "WARN" "Flow logs S3 bucket not found"
  track_result 2
fi

# Summary
echo
echo "=== Health Check Summary ==="
echo "Total checks: $CHECKS_TOTAL"
echo "Passed: $CHECKS_PASSED"
echo "Failed: $CHECKS_FAILED"
echo "Warnings: $CHECKS_WARNED"

if [ $CHECKS_FAILED -eq 0 ]; then
  print_status "PASS" "All critical checks passed!"
  exit 0
else
  print_status "FAIL" "Some critical checks failed. Review output above."
  exit 1
fi