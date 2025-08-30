# IAM role for VM-Series
resource "aws_iam_role" "vmseries" {
  name = "vmseries-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, { Name = "vmseries-role" })
}

# HIGH RISK FIX: Strengthen IAM policies with least privilege
resource "aws_iam_role_policy" "vmseries_least_privilege" {
  name = "vmseries-least-privilege-policy"
  role = aws_iam_role.vmseries.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "ssm:UpdateInstanceInformation",
          "ssm:ListAssociations",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion": [var.aws_region]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::vmseries-bootstrap-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::vmseries-bootstrap-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Effect = "Deny",
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "ec2:TerminateInstances",
          "ec2:StopInstances"
        ],
        Resource = "*",
        Condition = {
          StringNotEquals = {
            "aws:PrincipalType": "AssumedRole"
          }
        }
      }
    ]
  })
}

# Attach AWS managed policies only if necessary
resource "aws_iam_role_policy_attachment" "vmseries_ssm" {
  role       = aws_iam_role.vmseries.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vmseries" {
  name = "vmseries-profile"
  role = aws_iam_role.vmseries.name
}

# KMS key for EBS encryption
resource "aws_kms_key" "ebs" {
  description             = "KMS key for VM-Series EBS encryption"
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

  tags = merge(var.tags, { Name = "vmseries-ebs-encryption-key" })
}

# Launch template with EBS encryption
resource "aws_launch_template" "vmseries" {
  name_prefix   = "vmseries-"
  image_id      = data.aws_ami.vmseries.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.vmseries.name
  }

  network_interfaces {
    device_index                = 0
    subnet_id                   = var.subnet_ids[0]
    associate_public_ip_address = false
    security_groups             = [aws_security_group.vmseries.id]
  }

  # CRITICAL FIX: Enable EBS encryption with proper configuration
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      encrypted             = true
      kms_key_id           = aws_kms_key.ebs.arn
      volume_size          = 60
      volume_type          = "gp3"
      delete_on_termination = true
      iops                 = 3000
      throughput           = 125
    }
  }

  # Add secondary EBS volume for logging
  block_device_mappings {
    device_name = "/dev/sdb"

    ebs {
      encrypted             = true
      kms_key_id           = aws_kms_key.ebs.arn
      volume_size          = 40
      volume_type          = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/bootstrap.xml.tpl", {
    panorama_ip       = var.panorama_ip
    panorama_username = var.panorama_username
    panorama_password = var.panorama_password
  }))

  # Enhanced tags with operational metadata - LOW RISK IMPROVEMENT
  tags = merge(var.tags, {
    Name            = "vmseries-lt"
    Component       = "firewall"
    AutoScaling     = "enabled"
    BootstrapStatus = "pending"
    SecurityLevel   = "high"
  })

  # Enhanced security hardening - LOW RISK IMPROVEMENT
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  # Lifecycle management for zero-downtime updates - LOW RISK IMPROVEMENT
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to user_data to prevent bootstrap loops
      user_data,
      # Ignore tag changes that happen during runtime
      tags["BootstrapStatus"]
    ]
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# AMI data source
data "aws_ami" "vmseries" {
  most_recent = true
  owners      = ["679593333241"] # Palo Alto Networks

  filter {
    name   = "name"
    values = ["PA-VM-AWS-${var.vmseries_version}*"]
  }
}

# Security group
resource "aws_security_group" "vmseries" {
  name_prefix = "vmseries-sg-"
  vpc_id      = var.vpc_id

  # CRITICAL FIX: Restrict SSH access to specific CIDR blocks
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.management_cidrs != [] ? var.management_cidrs : [var.inspection_vpc_cidr]
    description     = "SSH access for management"
  }

  # Allow GENEVE traffic from GWLB
  ingress {
    from_port       = 6081
    to_port         = 6081
    protocol        = "udp"
    cidr_blocks     = [var.inspection_vpc_cidr]
    description     = "GENEVE traffic from Gateway Load Balancer"
  }

  # Allow health check traffic
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.inspection_vpc_cidr]
    description     = "Health check traffic"
  }

  # CRITICAL FIX: Restrictive egress rules
  egress {
    from_port   = 3978
    to_port     = 3978
    protocol    = "tcp"
    cidr_blocks = var.panorama_ip != "" ? [var.panorama_ip] : []
    description = "Panorama management traffic"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for updates and API calls"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS queries"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS queries"
  }

  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NTP synchronization"
  }

  tags = merge(var.tags, { Name = "vmseries-sg" })
}

# Autoscaling group
resource "aws_autoscaling_group" "vmseries" {
  name_prefix         = "vmseries-asg-"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.min_size
  vpc_zone_identifier = var.subnet_ids
  launch_template {
    id      = aws_launch_template.vmseries.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "vmseries"
    propagate_at_launch = true
  }
}

# Attach to target group
resource "aws_autoscaling_attachment" "vmseries" {
  autoscaling_group_name = aws_autoscaling_group.vmseries.name
  lb_target_group_arn    = var.target_group_arn
}

# Bootstrap S3 bucket for VM-Series configuration - CRITICAL FIX
resource "aws_s3_bucket" "bootstrap" {
  bucket = "vmseries-bootstrap-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name    = "vmseries-bootstrap"
    Purpose = "firewall-bootstrap"
  })
}

resource "aws_s3_bucket_versioning" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bootstrap configuration files
resource "aws_s3_object" "bootstrap_xml" {
  bucket = aws_s3_bucket.bootstrap.id
  key    = "config/bootstrap.xml"
  content = templatefile("${path.module}/bootstrap.xml.tpl", {
    panorama_ip       = var.panorama_ip
    panorama_username = var.panorama_username
    panorama_password = var.panorama_password
  })
  server_side_encryption = "AES256"
}

resource "aws_s3_object" "init_cfg" {
  bucket = aws_s3_bucket.bootstrap.id
  key    = "config/init-cfg.txt"
  content = templatefile("${path.module}/init-cfg.txt.tpl", {
    panorama_ip       = var.panorama_ip
    panorama_username = var.panorama_username
    auth_key          = var.panorama_password
  })
  server_side_encryption = "AES256"
}

# Bootstrap template file (for reference)
resource "local_file" "bootstrap_template" {
  filename = "${path.module}/bootstrap.xml.tpl"
  content  = file("${path.module}/bootstrap.xml.tpl")
}