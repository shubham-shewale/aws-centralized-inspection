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

  # CRITICAL FIX: Enable EBS encryption
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      encrypted   = true
      kms_key_id  = aws_kms_key.ebs.arn
      volume_size = 60
      volume_type = "gp3"
    }
  }

  user_data = base64encode(templatefile("${path.module}/bootstrap.xml.tpl", {
    panorama_ip       = var.panorama_ip
    panorama_username = var.panorama_username
    panorama_password = var.panorama_password
  }))

  tags = merge(var.tags, { Name = "vmseries-lt" })

  # Security hardening
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
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

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

# Bootstrap template
resource "local_file" "bootstrap" {
  filename = "${path.module}/bootstrap.xml.tpl"
  content  = <<EOF
<vm-series>
  <type>
    <dhcp-client>
      <send-hostname>yes</send-hostname>
      <send-client-id>yes</send-client-id>
      <accept-dhcp-hostname>no</accept-dhcp-hostname>
      <accept-dhcp-domain>no</accept-dhcp-domain>
    </dhcp-client>
  </type>
  <panorama-server>${var.panorama_ip}</panorama-server>
  <auth-key>${var.panorama_password}</auth-key>
  <dgname>aws-dg</dgname>
  <tplname>aws-template</tplname>
</vm-series>
EOF
}