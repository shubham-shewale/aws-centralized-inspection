#!/bin/bash

set -e

echo "Running routing symmetry checks for AWS Centralized Inspection..."

# Load variables
SPOKE_VPC_CIDRS=${SPOKE_VPC_CIDRS:-"10.1.0.0/16 10.2.0.0/16"}
INSPECTION_VPC_ID=${INSPECTION_VPC_ID:-""}
SPOKE_VPC_IDS=${SPOKE_VPC_IDS:-""}

# Function to check routes
check_routes() {
  local rt_id=$1
  local expected_target=$2
  local destination=$3

  echo "Checking route table $rt_id for destination $destination..."
  ROUTE_TARGET=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query "RouteTables[0].Routes[?DestinationCidrBlock=='$destination'].VpcEndpointId" --output text 2>/dev/null || echo "not-found")

  if [ "$ROUTE_TARGET" = "$expected_target" ]; then
    echo "✓ Route correctly configured"
  else
    echo "✗ Route misconfigured. Expected: $expected_target, Found: $ROUTE_TARGET"
  fi
}

# Get route tables
if [ -n "$INSPECTION_VPC_ID" ]; then
  INSPECTION_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$INSPECTION_VPC_ID" "Name=tag:Name,Values=*private*" --query 'RouteTables[0].RouteTableId' --output text)
  echo "Inspection private route table: $INSPECTION_RT"
fi

# For each spoke VPC
for VPC_ID in $SPOKE_VPC_IDS; do
  if [ -n "$VPC_ID" ]; then
    SPOKE_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[0].RouteTableId' --output text)
    echo "Spoke route table for $VPC_ID: $SPOKE_RT"

    # Get VPC endpoint ID for this VPC
    ENDPOINT_ID=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=*gwlb*" --query 'VpcEndpoints[0].VpcEndpointId' --output text 2>/dev/null || echo "not-found")

    if [ "$ENDPOINT_ID" != "not-found" ]; then
      # Check routes to other spokes
      for CIDR in $SPOKE_VPC_CIDRS; do
        if ! aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock' --output text | grep -q "$CIDR"; then
          check_routes $SPOKE_RT $ENDPOINT_ID $CIDR
        fi
      done
    fi
  fi
done

echo "Routing checks completed."