# Inspection VPC
resource "aws_vpc" "inspection" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "inspection-vpc" })
}

# Public subnets for GWLB
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id            = aws_vpc.inspection.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "inspection-public-${count.index}" })
}

# Private subnets for firewalls
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.inspection.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "inspection-private-${count.index}" })
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.inspection.id

  tags = merge(var.tags, { Name = "inspection-igw" })
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = length(var.public_subnets)

  domain = "vpc"

  tags = merge(var.tags, { Name = "inspection-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = length(var.public_subnets)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "inspection-nat-${count.index}" })
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.inspection.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "inspection-public-rt" })
}

resource "aws_route_table" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.inspection.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(var.tags, { Name = "inspection-private-rt-${count.index}" })
}

# Network ACLs for enhanced security - CRITICAL FIX
resource "aws_network_acl" "inspection" {
  vpc_id = aws_vpc.inspection.id

  # Allow all traffic within VPC
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow traffic from spoke VPCs
  dynamic "ingress" {
    for_each = var.spoke_vpc_cidrs
    content {
      protocol   = "-1"
      rule_no    = 200 + index(var.spoke_vpc_cidrs, ingress.value)
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 0
    }
  }

  # Deny all other inbound
  ingress {
    protocol   = "-1"
    rule_no    = 1000
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, { Name = "inspection-nacl" })
}

# Associate NACL with subnets
resource "aws_network_acl_association" "inspection_public" {
  count = length(var.public_subnets)

  network_acl_id = aws_network_acl.inspection.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_network_acl_association" "inspection_private" {
  count = length(var.private_subnets)

  network_acl_id = aws_network_acl.inspection.id
  subnet_id      = aws_subnet.private[count.index].id
}

# Route table associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Spoke VPCs
resource "aws_vpc" "spoke" {
  count = length(var.spoke_vpc_cidrs)

  cidr_block           = var.spoke_vpc_cidrs[count.index]
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "spoke-vpc-${count.index}" })
}

# Spoke private subnets
resource "aws_subnet" "spoke_private" {
  count = length(var.spoke_vpc_cidrs) * length(var.spoke_azs)

  vpc_id            = aws_vpc.spoke[floor(count.index / length(var.spoke_azs))].id
  cidr_block        = var.spoke_private_subnets[floor(count.index / length(var.spoke_azs))][count.index % length(var.spoke_azs)]
  availability_zone = var.spoke_azs[count.index % length(var.spoke_azs)]

  tags = merge(var.tags, { Name = "spoke-private-${floor(count.index / length(var.spoke_azs))}-${count.index % length(var.spoke_azs)}" })
}

# Spoke route tables
resource "aws_route_table" "spoke" {
  count = length(var.spoke_vpc_cidrs)

  vpc_id = aws_vpc.spoke[count.index].id

  tags = merge(var.tags, { Name = "spoke-rt-${count.index}" })
}

# Spoke route table associations
resource "aws_route_table_association" "spoke" {
  count = length(var.spoke_vpc_cidrs) * length(var.spoke_azs)

  subnet_id      = aws_subnet.spoke_private[count.index].id
  route_table_id = aws_route_table.spoke[floor(count.index / length(var.spoke_azs))].id
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Transit Gateway for centralized inspection"
  amazon_side_asn                 = var.tgw_asn
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, { Name = "inspection-tgw" })
}

# TGW VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  subnet_ids         = aws_subnet.private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.inspection.id

  tags = merge(var.tags, { Name = "inspection-tgw-attachment" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  count = length(var.spoke_vpc_cidrs)

  subnet_ids         = [for i in range(length(var.spoke_azs)) : aws_subnet.spoke_private[count.index * length(var.spoke_azs) + i].id]
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.spoke[count.index].id

  tags = merge(var.tags, { Name = "spoke-tgw-attachment-${count.index}" })
}

# TGW Route Tables
resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, { Name = "inspection-tgw-rt" })
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, { Name = "spoke-tgw-rt" })
}

# TGW Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  count = length(var.spoke_vpc_cidrs)

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# VPC Flow Logs - HIGH RISK FIX
resource "aws_flow_log" "inspection_vpc" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.inspection.id

  tags = merge(var.tags, { Name = "inspection-vpc-flow-logs" })
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  name = "inspection-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "flow-log-role" })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "inspection-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/inspection"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "inspection-flow-logs" })
}

# TGW Flow Logs
resource "aws_ec2_transit_gateway_flow_log" "this" {
  transit_gateway_id             = aws_ec2_transit_gateway.this.id
  iam_role_arn                   = aws_iam_role.flow_log.arn
  log_destination_type           = "cloud-watch-logs"
  log_destination                = aws_cloudwatch_log_group.tgw_flow_logs.arn
  max_aggregation_interval       = 60

  tags = merge(var.tags, { Name = "tgw-flow-logs" })
}

resource "aws_cloudwatch_log_group" "tgw_flow_logs" {
  name              = "/aws/tgw/flow-logs/inspection"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "tgw-flow-logs" })
}

# TGW Route Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "inspection_to_spoke" {
  count = length(var.spoke_vpc_cidrs)

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_inspection" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}