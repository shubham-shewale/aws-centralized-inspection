output "vpc_flow_log_ids" {
  description = "IDs of VPC flow logs"
  value       = aws_flow_log.vpc[*].id
}

output "tgw_flow_log_id" {
  description = "ID of TGW flow log"
  value       = aws_flow_log.tgw[*].id
}