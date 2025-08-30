resource "panos_security_rule" "rules" {
  count = length(var.security_rules)

  name                  = var.security_rules[count.index].name
  action                = var.security_rules[count.index].action
  source_zones          = var.security_rules[count.index].source_zones
  destination_zones     = var.security_rules[count.index].destination_zones
  source_addresses      = var.security_rules[count.index].source_addresses
  destination_addresses = var.security_rules[count.index].destination_addresses
  applications          = var.security_rules[count.index].applications
  services              = var.security_rules[count.index].services
  device_group          = var.device_group
}