# Security group for GWLB - CRITICAL FIX: Restrict ingress
resource "aws_security_group" "gwlb" {
  name_prefix = "gwlb-sg-"
  vpc_id      = var.inspection_vpc_id

  # CRITICAL FIX: Restrict ingress to spoke VPCs only
  ingress {
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = var.spoke_vpc_cidrs
    description = "Allow GENEVE traffic from spoke VPCs"
  }

  # Allow health checks from inspection VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.inspection_vpc_cidr]
    description = "Allow SSH health checks"
  }

  # Restrictive egress - only necessary traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.spoke_vpc_cidrs, [var.inspection_vpc_cidr])
    description = "Allow traffic to spoke VPCs and inspection VPC"
  }

  tags = merge(var.tags, {
    Name        = "gwlb-sg"
    Purpose     = "traffic-inspection"
    Environment = var.tags["Environment"]
  })
}

# GWLB
resource "aws_lb" "gwlb" {
  name               = "inspection-gwlb"
  internal           = true
  load_balancer_type = "gateway"
  subnets            = var.public_subnet_ids  # Assuming public for now, can change to private
  security_groups    = [aws_security_group.gwlb.id]

  tags = merge(var.tags, { Name = "inspection-gwlb" })
}

# Target group
resource "aws_lb_target_group" "gwlb" {
  name     = "inspection-tg"
  protocol = "GENEVE"
  port     = 6081
  vpc_id   = var.inspection_vpc_id
  target_type = "ip"

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = 22
  }

  tags = merge(var.tags, { Name = "inspection-tg" })
}

# Listener
resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb.arn
  }
}

# Endpoint service
resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(var.tags, { Name = "inspection-gwlb-service" })
}

# VPC endpoints in spoke VPCs
resource "aws_vpc_endpoint" "gwlb" {
  count = length(var.spoke_vpc_ids)

  vpc_id            = var.spoke_vpc_ids[count.index]
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = slice(var.spoke_private_subnet_ids, count.index * 2, (count.index + 1) * 2)

  tags = merge(var.tags, { Name = "spoke-gwlb-endpoint-${count.index}" })
}

# Routes in spoke route tables for cross-spoke traffic
resource "aws_route" "spoke_to_gwlb" {
  count = length(var.spoke_route_table_ids) * (length(var.spoke_vpc_cidrs) - 1)

  route_table_id         = var.spoke_route_table_ids[floor(count.index / (length(var.spoke_vpc_cidrs) - 1))]
  destination_cidr_block = var.spoke_vpc_cidrs[(count.index % (length(var.spoke_vpc_cidrs) - 1)) + (floor(count.index / (length(var.spoke_vpc_cidrs) - 1)) < (count.index % (length(var.spoke_vpc_cidrs) - 1)) ? 0 : 1)]
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb[floor(count.index / (length(var.spoke_vpc_cidrs) - 1))].id
}

# Routes in inspection private route tables for return traffic
# Note: For east-west traffic, return routes should go through TGW for symmetry
resource "aws_route" "inspection_to_spoke" {
  count = length(var.inspection_private_route_table_ids) * length(var.spoke_vpc_cidrs)

  route_table_id         = var.inspection_private_route_table_ids[floor(count.index / length(var.spoke_vpc_cidrs))]
  destination_cidr_block = var.spoke_vpc_cidrs[count.index % length(var.spoke_vpc_cidrs)]
  transit_gateway_id     = var.transit_gateway_id
}

# Routes for internet-bound traffic from inspection VPC
resource "aws_route" "inspection_to_internet" {
  count = length(var.inspection_private_route_table_ids)

  route_table_id         = var.inspection_private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

# AWS Shield Advanced for DDoS Protection - HIGH RISK FIX
resource "aws_shield_protection" "gwlb" {
  name         = "inspection-gwlb-ddos-protection"
  resource_arn = aws_lb.gwlb.arn

  tags = merge(var.tags, { Name = "gwlb-shield-protection" })
}

# AWS Shield protection for associated resources
resource "aws_shield_protection" "alb" {
  count        = var.enable_internet_facing ? 1 : 0
  name         = "inspection-alb-ddos-protection"
  resource_arn = var.internet_facing_alb_arn

  tags = merge(var.tags, { Name = "alb-shield-protection" })
}

# Note: GWLB routing requires careful configuration for symmetric flows
# Ensure TGW route tables are properly configured for return-path symmetry