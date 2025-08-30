# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? length(var.vpc_ids) : 0

  vpc_id               = var.vpc_ids[count.index]
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.log_bucket_arn

  tags = merge(var.tags, { Name = "vpc-flow-log-${count.index}" })
}

# TGW Flow Logs
resource "aws_flow_log" "tgw" {
  count = var.enable_flow_logs ? 1 : 0

  transit_gateway_id   = var.tgw_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.log_bucket_arn

  tags = merge(var.tags, { Name = "tgw-flow-log" })
}

# Traffic Mirroring (placeholder - requires specific ENI IDs for sessions)
# Note: Traffic mirroring setup requires identifying source ENIs and creating mirror targets, filters, and sessions.
# This is a basic placeholder; actual implementation would need ENI IDs from firewall instances.