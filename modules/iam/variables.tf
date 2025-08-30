variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "trusted_account_arns" {
  description = "List of trusted account ARNs for cross-account access"
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges for cross-account access"
  type        = list(string)
  default     = []
}

variable "allowed_principal_arns" {
  description = "List of allowed principal ARNs for cross-account access"
  type        = list(string)
  default     = []
}

variable "allowed_regions" {
  description = "List of allowed AWS regions"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}