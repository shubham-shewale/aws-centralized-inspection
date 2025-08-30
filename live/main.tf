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

# Data source for AZs with proper filtering
data "aws_availability_zones" "available" {
  state = "available"

  # Filter out Local Zones and Wavelength Zones for production stability
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

# IAM Security Module - HIGH RISK FIX
module "iam" {
  source = "../modules/iam"

  environment           = "production"
  trusted_account_arns  = var.trusted_account_arns
  allowed_ip_ranges     = var.allowed_ip_ranges
  allowed_principal_arns = var.allowed_principal_arns
  allowed_regions       = var.allowed_regions
  tags                  = var.tags
}

# Inspection module (for VM-Series)
module "inspection" {
  count  = var.inspection_engine == "vmseries" ? 1 : 0
  source = "../modules/inspection"

  inspection_vpc_id             = module.network.inspection_vpc_id
  inspection_vpc_cidr           = var.vpc_cidr
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

  aws_region           = var.aws_region
  vpc_id               = module.network.inspection_vpc_id
  subnet_ids           = module.network.inspection_private_subnet_ids
  target_group_arn     = module.inspection[0].target_group_arn
  vmseries_version     = var.vmseries_version
  instance_type        = var.vmseries_instance_type
  min_size             = var.vmseries_min_size
  max_size             = var.vmseries_max_size
  key_name             = var.key_name
  panorama_ip          = var.panos_hostname
  panorama_username    = var.panos_username
  panorama_password    = var.panos_password
  management_cidrs     = var.allowed_ip_ranges
  inspection_vpc_cidr  = var.vpc_cidr
  tags                 = var.tags
}

# Firewall Cloud NGFW
module "firewall_cloudngfw" {
  count  = var.inspection_engine == "cloudngfw" ? 1 : 0
  source = "../modules/firewall-cloudngfw"

  rule_stack_name     = var.cloudngfw_rule_stack_name
  inspection_vpc_cidrs = [var.vpc_cidr]
  spoke_vpc_cidrs     = var.spoke_vpc_cidrs
  tags                = var.tags
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

# S3 bucket for logs with comprehensive security - CRITICAL SECURITY FIX
resource "aws_s3_bucket" "logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = "aws-centralized-inspection-logs-${random_string.suffix.result}"

  tags = merge(var.tags, {
    Name        = "inspection-logs"
    Purpose     = "flow-logs-storage"
    DataClassification = "sensitive"
    EncryptionAtRest  = "required"
  })
}

resource "aws_s3_bucket_versioning" "logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# CRITICAL: Use KMS encryption instead of AES256 for better security
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CRITICAL: Add lifecycle configuration for log retention
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "log_retention"
    status = "Enabled"

    # Move to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete after 365 days
    expiration {
      days = 365
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CRITICAL: Add KMS key for S3 encryption
resource "aws_kms_key" "logs" {
  count = var.enable_flow_logs ? 1 : 0

  description             = "KMS key for inspection logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "inspection-logs-encryption"
  })
}

# KMS key for state encryption - CRITICAL SECURITY FIX
resource "aws_kms_key" "state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-user"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalType": "User"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "terraform-state-encryption"
    Purpose = "state-encryption"
  })
}

# KMS key alias for better management
resource "aws_kms_alias" "state" {
  name          = "alias/terraform-state-encryption"
  target_key_id = aws_kms_key.state.key_id
}

# Data source for account information
data "aws_caller_identity" "current" {}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}