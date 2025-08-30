#!/bin/bash

set -e

echo "Running health checks for AWS Centralized Inspection..."

# Load variables from environment or terraform output
# Set these variables before running the script
INSPECTION_VPC_ID=${INSPECTION_VPC_ID:-""}
TGW_ID=${TGW_ID:-""}
GWLB_NAME=${GWLB_NAME:-"inspection-gwlb"}
INSTANCE_TAG=${INSTANCE_TAG:-"vmseries"}

# Function to check resource state
check_resource() {
  local resource_type=$1
  local check_command=$2
  local expected=$3

  echo "Checking $resource_type..."
  if eval "$check_command" | grep -q "$expected"; then
    echo "✓ $resource_type is healthy"
  else
    echo "✗ $resource_type check failed"
    return 1
  fi
}

# Check Inspection VPC
if [ -n "$INSPECTION_VPC_ID" ]; then
  check_resource "Inspection VPC" "aws ec2 describe-vpcs --vpc-ids $INSPECTION_VPC_ID --query 'Vpcs[0].State' --output text" "available"
fi

# Check Transit Gateway
if [ -n "$TGW_ID" ]; then
  check_resource "Transit Gateway" "aws ec2 describe-transit-gateways --transit-gateway-ids $TGW_ID --query 'TransitGateways[0].State' --output text" "available"
fi

# Check Gateway Load Balancer
check_resource "Gateway Load Balancer" "aws elbv2 describe-load-balancers --names $GWLB_NAME --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null" "active" || echo "GWLB not found or not active"

# Check VM-Series instances
echo "Checking VM-Series instances..."
INSTANCE_COUNT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCE_TAG" "Name=instance-state-name,Values=running" --query 'Reservations | length(@)' --output text)
if [ "$INSTANCE_COUNT" -gt 0 ]; then
  echo "✓ Found $INSTANCE_COUNT running VM-Series instances"
else
  echo "✗ No running VM-Series instances found"
fi

# Check VPC endpoints
echo "Checking VPC endpoints..."
ENDPOINT_COUNT=$(aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=*gwlb*" --query 'VpcEndpoints | length(@)' --output text)
if [ "$ENDPOINT_COUNT" -gt 0 ]; then
  echo "✓ Found $ENDPOINT_COUNT GWLB VPC endpoints"
else
  echo "✗ No GWLB VPC endpoints found"
fi

echo "Health checks completed."