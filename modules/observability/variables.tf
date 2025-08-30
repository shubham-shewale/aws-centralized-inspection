variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
}

variable "enable_traffic_mirroring" {
  description = "Enable Traffic Mirroring"
  type        = bool
}

variable "vpc_ids" {
  description = "IDs of VPCs to enable flow logs"
  type        = list(string)
}

variable "tgw_id" {
  description = "ID of the Transit Gateway"
  type        = string
}

variable "log_bucket_arn" {
  description = "ARN of the S3 bucket for logs"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}