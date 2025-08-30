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