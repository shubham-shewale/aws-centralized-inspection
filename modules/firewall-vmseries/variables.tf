variable "vpc_id" {
  description = "ID of the inspection VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of the private subnets for firewalls"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the GWLB target group"
  type        = string
}

variable "vmseries_version" {
  description = "VM-Series software version"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for VM-Series"
  type        = string
}

variable "min_size" {
  description = "Minimum number of VM-Series instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of VM-Series instances"
  type        = number
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "panorama_ip" {
  description = "IP address of Panorama"
  type        = string
}

variable "panorama_username" {
  description = "Panorama username"
  type        = string
}

variable "panorama_password" {
  description = "Panorama password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}