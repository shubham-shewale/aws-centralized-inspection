output "security_rule_names" {
  description = "Names of the security rules"
  value       = panos_security_rule.rules[*].name
}