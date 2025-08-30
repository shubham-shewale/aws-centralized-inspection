# Network outputs
output "inspection_vpc_id" {
  description = "ID of the inspection VPC"
  value       = module.network.inspection_vpc_id
}

output "spoke_vpc_ids" {
  description = "IDs of the spoke VPCs"
  value       = module.network.spoke_vpc_ids
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = module.network.transit_gateway_id
}

# Inspection outputs
output "gwlb_arn" {
  description = "ARN of the Gateway Load Balancer"
  value       = var.inspection_engine == "vmseries" ? module.inspection[0].gwlb_arn : null
}

output "endpoint_service_name" {
  description = "Name of the VPC endpoint service"
  value       = var.inspection_engine == "vmseries" ? module.inspection[0].endpoint_service_name : null
}

# Firewall outputs
output "vmseries_asg_name" {
  description = "Name of the VM-Series autoscaling group"
  value       = var.inspection_engine == "vmseries" ? module.firewall_vmseries[0].autoscaling_group_name : null
}

output "cloudngfw_rule_stack_arn" {
  description = "ARN of the Cloud NGFW rule stack"
  value       = var.inspection_engine == "cloudngfw" ? module.firewall_cloudngfw[0].rule_stack_arn : null
}

# Observability outputs
output "vpc_flow_log_ids" {
  description = "IDs of VPC flow logs"
  value       = module.observability.vpc_flow_log_ids
}

output "tgw_flow_log_id" {
  description = "ID of TGW flow log"
  value       = module.observability.tgw_flow_log_id
}