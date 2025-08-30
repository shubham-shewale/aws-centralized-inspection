resource "cloudngfwaws_rule_stack" "this" {
  name        = var.rule_stack_name
  scope       = "Local"
  description = "Rule stack for centralized inspection"

  rules = [
    {
      name = "allow-all"
      action = "Allow"
      source = {
        cidrs = ["0.0.0.0/0"]
      }
      destination = {
        cidrs = ["0.0.0.0/0"]
      }
      applications = ["any"]
      services     = ["any"]
      logging      = true
    }
  ]

  tags = var.tags
}