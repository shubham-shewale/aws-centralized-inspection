# Network module
module "network" {
  source = "../modules/network"

  vpc_cidr           = var.vpc_cidr
  azs                = data.aws_availability_zones.available.names
  public_subnets     = [for i in range(length(data.aws_availability_zones.available.names)) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets    = [for i in range(length(data.aws_availability_zones.available.names)) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  tgw_asn            = var.tgw_asn
  spoke_vpc_cidrs    = var.spoke_vpc_cidrs
  spoke_azs          = data.aws_availability_zones.available.names
  spoke_private_subnets = [for cidr in var.spoke_vpc_cidrs : [for i in range(length(data.aws_availability_zones.available.names)) : cidrsubnet(cidr, 8, i)]]
  tags               = var.tags
}

# Data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Inspection module (for VM-Series)
module "inspection" {
  count  = var.inspection_engine == "vmseries" ? 1 : 0
  source = "../modules/inspection"

  inspection_vpc_id             = module.network.inspection_vpc_id
  public_subnet_ids             = module.network.inspection_public_subnet_ids
  spoke_vpc_ids                 = module.network.spoke_vpc_ids
  spoke_private_subnet_ids      = module.network.spoke_private_subnet_ids
  spoke_vpc_cidrs               = var.spoke_vpc_cidrs
  spoke_route_table_ids         = module.network.spoke_route_table_ids
  inspection_private_route_table_ids = module.network.inspection_private_route_table_ids
  transit_gateway_id            = module.network.transit_gateway_id
  internet_gateway_id           = module.network.internet_gateway_id
  tags                          = var.tags
}

# Firewall VM-Series
module "firewall_vmseries" {
  count  = var.inspection_engine == "vmseries" ? 1 : 0
  source = "../modules/firewall-vmseries"

  vpc_id             = module.network.inspection_vpc_id
  subnet_ids         = module.network.inspection_private_subnet_ids
  target_group_arn   = module.inspection[0].target_group_arn
  vmseries_version   = var.vmseries_version
  instance_type      = var.vmseries_instance_type
  min_size           = var.vmseries_min_size
  max_size           = var.vmseries_max_size
  key_name           = var.key_name
  panorama_ip        = var.panos_hostname
  panorama_username  = var.panos_username
  panorama_password  = var.panos_password
  tags               = var.tags
}

# Firewall Cloud NGFW
module "firewall_cloudngfw" {
  count  = var.inspection_engine == "cloudngfw" ? 1 : 0
  source = "../modules/firewall-cloudngfw"

  rule_stack_name = var.cloudngfw_rule_stack_name
  tags            = var.tags
}

# PAN-OS Config
module "panos_config" {
  count  = var.inspection_engine == "vmseries" && var.enable_panos_config ? 1 : 0
  source = "../modules/panos-config"

  panos_hostname  = var.panos_hostname
  panos_username  = var.panos_username
  panos_password  = var.panos_password
  device_group    = "aws-dg"
  template        = "aws-template"
  security_rules  = var.security_rules
  tags            = var.tags
}

# Observability
module "observability" {
  source = "../modules/observability"

  enable_flow_logs      = var.enable_flow_logs
  enable_traffic_mirroring = var.enable_traffic_mirroring
  vpc_ids               = concat([module.network.inspection_vpc_id], module.network.spoke_vpc_ids)
  tgw_id                = module.network.transit_gateway_id
  log_bucket_arn        = aws_s3_bucket.logs[0].arn
  tags                  = var.tags
}

# S3 bucket for logs (placeholder)
resource "aws_s3_bucket" "logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = "aws-centralized-inspection-logs-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}