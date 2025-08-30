variable "panos_hostname" {
  description = "PAN-OS hostname"
  type        = string
}

variable "panos_username" {
  description = "PAN-OS username"
  type        = string
}

variable "panos_password" {
  description = "PAN-OS password"
  type        = string
  sensitive   = true
}

variable "device_group" {
  description = "Device group name"
  type        = string
  default     = "aws-dg"
}

variable "template" {
  description = "Template name"
  type        = string
  default     = "aws-template"
}

variable "security_rules" {
  description = "List of security rules"
  type = list(object({
    name        = string
    action      = string
    source_zones = list(string)
    destination_zones = list(string)
    source_addresses = list(string)
    destination_addresses = list(string)
    applications = list(string)
    services     = list(string)
  }))
  default = [
    {
      name = "allow-all"
      action = "allow"
      source_zones = ["any"]
      destination_zones = ["any"]
      source_addresses = ["any"]
      destination_addresses = ["any"]
      applications = ["any"]
      services = ["any"]
    }
  ]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}