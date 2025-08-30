# Automated Security Remediation Module - MEDIUM RISK FIX

# Lambda function for automated security remediation - MEDIUM RISK FIX
resource "aws_lambda_function" "security_automation" {
  function_name = "inspection-security-automation"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  timeout       = 300

  role = aws_iam_role.lambda_execution.arn

  environment {
    variables = {
      INSPECTION_VPC_ID     = var.inspection_vpc_id
      SECURITY_SNS_TOPIC    = aws_sns_topic.security_alerts.arn
      LOG_GROUP_NAME        = aws_cloudwatch_log_group.automation_logs.name
      AUTO_REMEDIATE        = var.enable_auto_remediation ? "true" : "false"
    }
  }

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = merge(var.tags, {
    Name        = "security-automation-lambda"
    Purpose     = "automated-remediation"
    Environment = var.tags["Environment"]
  })
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  name = "inspection-security-automation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "lambda-execution-role" })
}

# IAM policy for Lambda remediation actions
resource "aws_iam_role_policy" "lambda_remediation" {
  name = "inspection-lambda-remediation-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeFlowLogs",
          "ec2:ModifyInstanceAttribute",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateFlowLogs",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sns:Publish"
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
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.security_automation.arn
      }
    ]
  })
}

# CloudWatch Events rule for automated remediation triggers
resource "aws_cloudwatch_event_rule" "security_events" {
  name        = "inspection-security-events"
  description = "Trigger automated remediation for security events"

  event_pattern = jsonencode({
    source = ["aws.ec2", "aws.elasticloadbalancing"]
    detail-type = [
      "AWS API Call via CloudTrail",
      "EC2 Instance State-change Notification",
      "ELB Application Load Balancer Request Count"
    ]
    detail = {
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "RevokeSecurityGroupIngress",
        "CreateSecurityGroup",
        "DeleteSecurityGroup"
      ]
    }
  })

  tags = merge(var.tags, { Name = "security-events-rule" })
}

# CloudWatch Events target
resource "aws_cloudwatch_event_target" "security_automation" {
  rule      = aws_cloudwatch_event_rule.security_events.name
  target_id = "security-automation-lambda"
  arn       = aws_lambda_function.security_automation.arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_automation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_events.arn
}

# SNS topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name = "inspection-security-alerts"

  tags = merge(var.tags, {
    Name        = "security-alerts"
    Purpose     = "security-notifications"
    Environment = var.tags["Environment"]
  })
}

# CloudWatch log group for automation logs
resource "aws_cloudwatch_log_group" "automation_logs" {
  name              = "/aws/lambda/inspection-security-automation"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "automation-logs" })
}

# Lambda function code (Python)
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<EOF
import json
import boto3
import os
import logging
from datetime import datetime

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Automated security remediation function
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Initialize AWS clients
        ec2 = boto3.client('ec2')
        sns = boto3.client('sns')

        # Get configuration from environment
        inspection_vpc_id = os.environ.get('INSPECTION_VPC_ID')
        sns_topic = os.environ.get('SECURITY_SNS_TOPIC')
        auto_remediate = os.environ.get('AUTO_REMEDIATE', 'false').lower() == 'true'

        # Analyze the security event
        if event.get('source') == 'aws.ec2':
            remediation_actions = handle_ec2_event(event, ec2, auto_remediate)
        elif event.get('source') == 'aws.elasticloadbalancing':
            remediation_actions = handle_elb_event(event, ec2, auto_remediate)
        else:
            remediation_actions = []

        # Send notification
        if remediation_actions:
            message = {
                'timestamp': datetime.utcnow().isoformat(),
                'event': event,
                'remediation_actions': remediation_actions,
                'auto_remediated': auto_remediate
            }

            sns.publish(
                TopicArn=sns_topic,
                Subject='Security Event Detected and Remediated',
                Message=json.dumps(message, indent=2)
            )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'remediation_actions': remediation_actions,
                'auto_remediated': auto_remediate
            })
        }

    except Exception as e:
        logger.error(f"Error processing security event: {str(e)}")
        raise

def handle_ec2_event(event, ec2, auto_remediate):
    """
    Handle EC2 security events
    """
    actions = []

    # Check for overly permissive security groups
    if event.get('detail', {}).get('eventName') in ['AuthorizeSecurityGroupIngress', 'CreateSecurityGroup']:
        group_id = event.get('detail', {}).get('requestParameters', {}).get('groupId')

        if group_id:
            # Check if security group allows 0.0.0.0/0
            response = ec2.describe_security_groups(GroupIds=[group_id])

            for sg in response['SecurityGroups']:
                for rule in sg.get('IpPermissions', []):
                    for ip_range in rule.get('IpRanges', []):
                        if ip_range.get('CidrIp') == '0.0.0.0/0':
                            actions.append({
                                'action': 'restrict_security_group',
                                'resource': group_id,
                                'issue': 'Overly permissive security group rule',
                                'remediation': 'Restrict 0.0.0.0/0 to specific IP ranges'
                            })

                            if auto_remediate:
                                # Remove overly permissive rule
                                ec2.revoke_security_group_ingress(
                                    GroupId=group_id,
                                    IpPermissions=[rule]
                                )

    return actions

def handle_elb_event(event, ec2, auto_remediate):
    """
    Handle ELB security events
    """
    actions = []

    # Check for unusual request patterns that might indicate attacks
    if event.get('detail', {}).get('requestCount', 0) > 10000:  # Threshold
        actions.append({
            'action': 'high_request_rate_detected',
            'resource': event.get('detail', {}).get('loadBalancer'),
            'issue': 'High request rate detected',
            'remediation': 'Enable AWS Shield Advanced and WAF'
        })

    return actions
EOF
    filename = "lambda_function.py"
  }
}

# CloudWatch Alarms for automated remediation triggers
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

# Additional automated remediation rules
resource "aws_cloudwatch_metric_alarm" "unusual_traffic" {
  alarm_name          = "inspection-unusual-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10000"
  alarm_description   = "Unusual traffic patterns detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    LoadBalancer = var.gwlb_arn
  }

  tags = merge(var.tags, { Name = "unusual-traffic-alarm" })
}