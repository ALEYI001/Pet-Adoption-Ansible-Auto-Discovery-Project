output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}

output "launch_template" {
  value = aws_launch_template.launch_config.name
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}
