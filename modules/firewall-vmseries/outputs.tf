output "autoscaling_group_name" {
  description = "Name of the VM-Series autoscaling group"
  value       = aws_autoscaling_group.vmseries.name
}

output "launch_template_id" {
  description = "ID of the VM-Series launch template"
  value       = aws_launch_template.vmseries.id
}

output "security_group_id" {
  description = "ID of the VM-Series security group"
  value       = aws_security_group.vmseries.id
}