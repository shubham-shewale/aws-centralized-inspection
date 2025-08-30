# Provider Configuration Variables
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = "default"
}

variable "aws_assume_role_arn" {
  description = "ARN of the role to assume for AWS provider"
  type        = string
  default     = ""
}

variable "panos_hostname" {
  description = "PAN-OS hostname for Panorama or firewall"
  type        = string
  default     = ""
}

variable "panos_username" {
  description = "PAN-OS username"
  type        = string
  default     = "admin"
}

variable "panos_password" {
  description = "PAN-OS password"
  type        = string
  sensitive   = true
  default     = ""
}

# Inspection Engine Selection
variable "inspection_engine" {
  description = "Inspection engine to use: 'vmseries' or 'cloudngfw'"
  type        = string
  default     = "vmseries"
  validation {
    condition     = contains(["vmseries", "cloudngfw"], var.inspection_engine)
    error_message = "Inspection engine must be either 'vmseries' or 'cloudngfw'."
  }
}

# Networking Variables
variable "vpc_cidr" {
  description = "CIDR block for the inspection VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tgw_asn" {
  description = "ASN for the Transit Gateway"
  type        = number
  default     = 64512
}

variable "spoke_vpc_cidrs" {
  description = "List of CIDR blocks for spoke VPCs"
  type        = list(string)
  default     = ["10.1.0.0/16", "10.2.0.0/16"]
}

# Feature Toggles
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "enable_traffic_mirroring" {
  description = "Enable Traffic Mirroring for observability"
  type        = bool
  default     = false
}

variable "enable_panos_config" {
  description = "Enable PAN-OS configuration management"
  type        = bool
  default     = true
}

# VM-Series Specific Variables
variable "vmseries_version" {
  description = "VM-Series software version"
  type        = string
  default     = "10.2.0"
}

variable "vmseries_instance_type" {
  description = "EC2 instance type for VM-Series"
  type        = string
  default     = "m5.xlarge"
}

variable "vmseries_min_size" {
  description = "Minimum number of VM-Series instances"
  type        = number
  default     = 2
}

variable "vmseries_max_size" {
  description = "Maximum number of VM-Series instances"
  type        = number
  default     = 4
}

# Cloud NGFW Specific Variables
variable "cloudngfw_rule_stack_name" {
  description = "Name of the Cloud NGFW rule stack"
  type        = string
  default     = "inspection-rule-stack"
}

# VM-Series SSH Key
variable "key_name" {
  description = "SSH key pair name for VM-Series instances"
  type        = string
  default     = ""
}

# Enhanced Security Rules for PAN-OS - LOW RISK IMPROVEMENT
variable "security_rules" {
  description = "List of security rules for PAN-OS configuration"
  type = list(object({
    name                = string
    action              = string
    source_zones        = list(string)
    destination_zones   = list(string)
    source_addresses    = list(string)
    destination_addresses = list(string)
    applications        = list(string)
    services            = list(string)
    description         = optional(string, "")
    tags                = optional(list(string), [])
    disabled            = optional(bool, false)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.security_rules : contains(["allow", "deny", "drop"], rule.action)
    ])
    error_message = "Security rule action must be one of: allow, deny, drop."
  }

  validation {
    condition = alltrue([
      for rule in var.security_rules : length(rule.name) > 0 && length(rule.name) <= 63
    ])
    error_message = "Security rule name must be between 1 and 63 characters."
  }
}

# Data Classification Tags - HIGH RISK FIX
variable "data_classification" {
  description = "Data classification level for resources"
  type        = string
  default     = "sensitive"
  validation {
    condition     = contains(["public", "internal", "sensitive", "restricted"], var.data_classification)
    error_message = "Data classification must be one of: public, internal, sensitive, restricted."
  }
}

# Enhanced Tags with Comprehensive Metadata - LOW RISK IMPROVEMENT
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    # Core identification
    Environment        = "production"
    Project           = "centralized-inspection"
    ManagedBy         = "terraform"
    Module            = "aws-centralized-inspection"

    # Security and compliance
    DataClassification = "sensitive"
    EncryptionAtRest  = "required"
    EncryptionInTransit = "required"
    Backup            = "required"
    DisasterRecovery = "required"

    # Operational metadata
    Owner             = "security-team"
    CostCenter        = "security-operations"
    Department        = "information-security"
    Team              = "network-security"

    # Compliance frameworks
    Compliance        = "pci-dss,hipaa,soc2,gdpr,nist-800-53"
    SecurityLevel     = "high"
    Confidentiality   = "restricted"
    Integrity         = "high"
    Availability      = "high"

    # Change management
    ChangeManagement = "required"
    ApprovalRequired = "security-review"
    MaintenanceWindow = "weekends-02:00-04:00-utc"

    # Monitoring and alerting
    Monitoring       = "enabled"
    Alerting         = "critical-only"
    LogRetention     = "365-days"

    # Cost optimization
    AutoShutdown     = "disabled"
    ReservedInstance = "eligible"
    SpotInstance     = "ineligible"
  }

  validation {
    condition = contains([
      "public", "internal", "sensitive", "restricted", "confidential"
    ], lookup(var.tags, "DataClassification", "sensitive"))
    error_message = "DataClassification must be one of: public, internal, sensitive, restricted, confidential."
  }

  validation {
    condition = contains([
      "none", "required", "optional"
    ], lookup(var.tags, "EncryptionAtRest", "required"))
    error_message = "EncryptionAtRest must be one of: none, required, optional."
  }
}