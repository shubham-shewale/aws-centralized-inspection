variable "rule_stack_name" {
  description = "Name of the Cloud NGFW rule stack"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}