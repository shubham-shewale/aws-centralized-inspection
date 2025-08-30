output "rule_stack_arn" {
  description = "ARN of the Cloud NGFW rule stack"
  value       = cloudngfwaws_rule_stack.this.arn
}