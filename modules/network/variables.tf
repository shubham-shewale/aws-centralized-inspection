variable "vpc_cidr" {
  description = "CIDR block for the inspection VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDRs for GWLB"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDRs for firewalls"
  type        = list(string)
}

variable "tgw_asn" {
  description = "ASN for the Transit Gateway"
  type        = number
}

variable "spoke_vpc_cidrs" {
  description = "List of CIDR blocks for spoke VPCs"
  type        = list(string)
}

variable "spoke_azs" {
  description = "List of AZs for spoke VPCs"
  type        = list(string)
}

variable "spoke_private_subnets" {
  description = "List of private subnet CIDRs for spoke VPCs"
  type        = list(list(string))
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}