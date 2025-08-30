variable "inspection_vpc_id" {
  description = "ID of the inspection VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "enable_auto_remediation" {
  description = "Enable automatic remediation of security issues"
  type        = bool
  default     = false
}

variable "gwlb_arn" {
  description = "ARN of the Gateway Load Balancer"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}