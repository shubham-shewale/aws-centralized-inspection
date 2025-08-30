output "inspection_vpc_id" {
  description = "ID of the inspection VPC"
  value       = aws_vpc.inspection.id
}

output "inspection_public_subnet_ids" {
  description = "IDs of the public subnets for GWLB"
  value       = aws_subnet.public[*].id
}

output "inspection_private_subnet_ids" {
  description = "IDs of the private subnets for firewalls"
  value       = aws_subnet.private[*].id
}

output "inspection_private_route_table_ids" {
  description = "IDs of the inspection private route tables"
  value       = aws_route_table.private[*].id
}

output "spoke_vpc_ids" {
  description = "IDs of the spoke VPCs"
  value       = aws_vpc.spoke[*].id
}

output "spoke_private_subnet_ids" {
  description = "IDs of the spoke private subnets"
  value       = aws_subnet.spoke_private[*].id
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "inspection_tgw_attachment_id" {
  description = "ID of the inspection TGW attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}

output "spoke_tgw_attachment_ids" {
  description = "IDs of the spoke TGW attachments"
  value       = aws_ec2_transit_gateway_vpc_attachment.spoke[*].id
}

output "inspection_tgw_route_table_id" {
  description = "ID of the inspection TGW route table"
  value       = aws_ec2_transit_gateway_route_table.inspection.id
}

output "spoke_tgw_route_table_id" {
  description = "ID of the spoke TGW route table"
  value       = aws_ec2_transit_gateway_route_table.spoke.id
}

output "spoke_route_table_ids" {
  description = "IDs of the spoke VPC route tables"
  value       = aws_route_table.spoke[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}