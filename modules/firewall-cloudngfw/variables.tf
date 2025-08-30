variable "rule_stack_name" {
  description = "Name of the Cloud NGFW rule stack"
  type        = string
}

variable "inspection_vpc_cidrs" {
  description = "CIDR blocks for inspection VPC"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_vpc_cidrs" {
  description = "CIDR blocks for spoke VPCs"
  type        = list(string)
  default     = ["10.1.0.0/16", "10.2.0.0/16"]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}