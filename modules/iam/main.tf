# IAM Security Module - HIGH RISK FIXES

# MFA Enforcement Policy
resource "aws_iam_policy" "mfa_required" {
  name        = "mfa-required-policy"
  description = "Policy that enforces MFA for privileged operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent": "false"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "mfa-required"
    Purpose     = "security-enforcement"
    Environment = var.environment
  }
}

# Cross-Account Access Role with Restrictions
resource "aws_iam_role" "cross_account_access" {
  name = "centralized-inspection-cross-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:PrincipalType": "AssumedRole"
          }
          IpAddress = {
            "aws:SourceIp": var.allowed_ip_ranges
          }
          StringLike = {
            "aws:PrincipalArn": var.allowed_principal_arns
          }
        }
      }
    ]
  })

  # Session duration limit
  max_session_duration = 3600

  tags = {
    Name        = "cross-account-access"
    Purpose     = "secure-cross-account"
    Environment = var.environment
  }
}

# Least Privilege Policy for Cross-Account Access
resource "aws_iam_role_policy" "cross_account_least_privilege" {
  name = "cross-account-least-privilege"
  role = aws_iam_role.cross_account_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "elasticloadbalancing:Describe*",
          "logs:Describe*",
          "logs:Get*",
          "cloudwatch:Get*",
          "cloudwatch:Describe*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion": var.allowed_regions
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::inspection-state-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::inspection-state-${data.aws_caller_identity.current.account_id}/*",
          "arn:aws:s3:::inspection-logs-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::inspection-logs-${data.aws_caller_identity.current.account_id}/*"
        ]
      }
    ]
  })
}

# Data source for account information
data "aws_caller_identity" "current" {}

# IAM Password Policy
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 12
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers               = true
  require_symbols               = true
  allow_users_to_change_password = true
  max_password_age              = 90
  password_reuse_prevention     = 5
}

# CloudTrail for Audit Logging
resource "aws_cloudtrail" "security_audit" {
  name                          = "inspection-security-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  s3_key_prefix                 = "security-audit"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Name        = "security-audit-trail"
    Purpose     = "compliance-logging"
    Environment = var.environment
  }
}

# S3 Bucket for Audit Logs
resource "aws_s3_bucket" "audit_logs" {
  bucket = "inspection-audit-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "audit-logs"
    Purpose     = "security-logging"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}