# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? length(var.vpc_ids) : 0

  vpc_id               = var.vpc_ids[count.index]
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.log_bucket_arn

  tags = merge(var.tags, { Name = "vpc-flow-log-${count.index}" })
}

# TGW Flow Logs
resource "aws_flow_log" "tgw" {
  count = var.enable_flow_logs ? 1 : 0

  transit_gateway_id   = var.tgw_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.log_bucket_arn

  tags = merge(var.tags, { Name = "tgw-flow-log" })
}

# Enhanced Monitoring and Alerting - MEDIUM RISK FIX

# CloudWatch Dashboard for Security Monitoring
resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = "inspection-security-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        properties = {
          metrics = [
            ["AWS/GatewayELB", "UnHealthyHostCount", "LoadBalancer", var.gwlb_arn],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.vmseries_asg_name],
            ["AWS/VPN", "TunnelState", "VpnId", var.vpn_id],
            ["Inspection", "ThreatCount"],
            ["Inspection", "BlockedConnections"],
            ["Inspection", "AnomalyScore"]
          ]
          title = "Security Metrics Overview"
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          stat = "Average"
          period = 300
        }
      },
      {
        type = "log",
        properties = {
          query = "SOURCE '${aws_cloudwatch_log_group.flow_logs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          title = "Recent Security Events"
          view = "table"
          region = var.aws_region
        }
      }
    ]
  })
}

# CloudWatch Alarms for Critical Security Events
resource "aws_cloudwatch_metric_alarm" "unhealthy_instances" {
  alarm_name          = "inspection-unhealthy-instances"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/GatewayELB"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Unhealthy instances detected in inspection infrastructure"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    LoadBalancer = var.gwlb_arn
  }

  tags = merge(var.tags, { Name = "unhealthy-instances-alarm" })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "inspection-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "High CPU utilization on firewall instances"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.vmseries_asg_name
  }

  tags = merge(var.tags, { Name = "high-cpu-alarm" })
}

resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "inspection-security-group-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityGroupChanges"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Security group changes detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = merge(var.tags, { Name = "security-group-changes-alarm" })
}

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  name = "inspection-security-alerts"

  tags = merge(var.tags, {
    Name        = "security-alerts"
    Purpose     = "security-notifications"
    Environment = var.tags["Environment"]
  })
}

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/inspection"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "flow-logs" })
}

# Traffic Mirroring Setup - MEDIUM RISK FIX
resource "aws_ec2_traffic_mirror_target" "nlb" {
  count = var.enable_traffic_mirroring ? 1 : 0

  network_load_balancer_arn = var.mirror_target_nlb_arn
  description              = "Traffic mirror target for inspection"

  tags = merge(var.tags, { Name = "traffic-mirror-target" })
}

resource "aws_ec2_traffic_mirror_filter" "inspection" {
  count = var.enable_traffic_mirroring ? 1 : 0

  description = "Traffic mirror filter for inspection"

  tags = merge(var.tags, { Name = "traffic-mirror-filter" })
}

resource "aws_ec2_traffic_mirror_filter_rule" "inbound" {
  count = var.enable_traffic_mirroring ? 1 : 0

  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.inspection[0].id
  destination_cidr_block  = "0.0.0.0/0"
  source_cidr_block       = "0.0.0.0/0"
  rule_number             = 1
  rule_action             = "accept"
  traffic_direction       = "ingress"
}

resource "aws_ec2_traffic_mirror_filter_rule" "outbound" {
  count = var.enable_traffic_mirroring ? 1 : 0

  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.inspection[0].id
  destination_cidr_block  = "0.0.0.0/0"
  source_cidr_block       = "0.0.0.0/0"
  rule_number             = 1
  rule_action             = "accept"
  traffic_direction       = "egress"
}

# Config Rules for Continuous Compliance Monitoring
resource "aws_config_config_rule" "s3_bucket_encryption" {
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  tags = merge(var.tags, { Name = "s3-encryption-config-rule" })
}

resource "aws_config_config_rule" "security_group_changes" {
  name = "security-group-changes-detected"

  source {
    owner             = "AWS"
    source_identifier = "EC2_SECURITY_GROUP_CHANGED"
  }

  tags = merge(var.tags, { Name = "security-group-changes-config-rule" })
}

# CloudWatch Logs Metric Filters for Custom Metrics
resource "aws_cloudwatch_log_metric_filter" "threat_detected" {
  name           = "threat-detected"
  pattern        = "[timestamp, level=ERROR, message=*threat*]"
  log_group_name = aws_cloudwatch_log_group.flow_logs.name

  metric_transformation {
    name      = "ThreatCount"
    namespace = "Inspection"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "blocked_connections" {
  name           = "blocked-connections"
  pattern        = "[timestamp, action=DENY, *]"
  log_group_name = aws_cloudwatch_log_group.flow_logs.name

  metric_transformation {
    name      = "BlockedConnections"
    namespace = "Inspection"
    value     = "1"
  }
}