variable "inspection_vpc_id" {
  description = "ID of the inspection VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets for GWLB"
  type        = list(string)
}

variable "spoke_vpc_ids" {
  description = "IDs of the spoke VPCs"
  type        = list(string)
}

variable "spoke_private_subnet_ids" {
  description = "IDs of the spoke private subnets"
  type        = list(string)
}

variable "spoke_vpc_cidrs" {
  description = "CIDR blocks of the spoke VPCs"
  type        = list(string)
}

variable "inspection_vpc_cidr" {
  description = "CIDR block of the inspection VPC"
  type        = string
}

variable "spoke_route_table_ids" {
  description = "IDs of the spoke route tables"
  type        = list(string)
}

variable "inspection_private_route_table_ids" {
  description = "IDs of the inspection private route tables"
  type        = list(string)
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  type        = string
}

variable "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  type        = string
}

variable "enable_internet_facing" {
  description = "Enable internet-facing ALB protection"
  type        = bool
  default     = false
}

variable "internet_facing_alb_arn" {
  description = "ARN of the internet-facing ALB to protect"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}