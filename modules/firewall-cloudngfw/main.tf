# CRITICAL SECURITY FIX: Replace overly permissive rule with secure defaults
resource "cloudngfwaws_rule_stack" "this" {
  name        = var.rule_stack_name
  scope       = "Local"
  description = "Secure rule stack for centralized inspection"

  rules = [
    # Allow essential traffic within inspection VPC
    {
      name = "allow-inspection-internal"
      action = "Allow"
      source = {
        cidrs = var.inspection_vpc_cidrs
      }
      destination = {
        cidrs = var.inspection_vpc_cidrs
      }
      applications = ["any"]
      services     = ["any"]
      logging      = true
      description  = "Allow internal traffic within inspection infrastructure"
    },
    # Allow DNS resolution
    {
      name = "allow-dns"
      action = "Allow"
      source = {
        cidrs = var.spoke_vpc_cidrs
      }
      destination = {
        cidrs = ["0.0.0.0/0"]
      }
      applications = ["dns"]
      services     = ["dns"]
      logging      = false
      description  = "Allow DNS resolution for spoke VPCs"
    },
    # Allow HTTPS traffic (can be customized based on requirements)
    {
      name = "allow-web-traffic"
      action = "Allow"
      source = {
        cidrs = var.spoke_vpc_cidrs
      }
      destination = {
        cidrs = ["0.0.0.0/0"]
      }
      applications = ["ssl", "web-browsing"]
      services     = ["https", "http"]
      logging      = true
      description  = "Allow web traffic from spoke VPCs"
    },
    # Default deny rule (must be last)
    {
      name = "default-deny"
      action = "Deny"
      source = {
        cidrs = ["0.0.0.0/0"]
      }
      destination = {
        cidrs = ["0.0.0.0/0"]
      }
      applications = ["any"]
      services     = ["any"]
      logging      = true
      description  = "Default deny all other traffic"
    }
  ]

  tags = merge(var.tags, {
    SecurityLevel = "high"
    Compliance    = "pci-dss,hipaa,soc2"
  })
}