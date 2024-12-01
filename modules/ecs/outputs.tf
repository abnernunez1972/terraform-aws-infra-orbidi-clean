output "security_group_id" {
  description = "ID del Security Group para ECS"
  value       = aws_security_group.ecs.id
}


output "alb_arn" {
  description = "ARN of the ECS Application Load Balancer"
  value       = aws_lb.ecs_alb.arn
}

output "autoscaling_group_name" {
  description = "Name of the ECS Auto Scaling Group"
  value       = aws_autoscaling_group.ecs_asg.name
}
output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.ecs_target_group.arn
}

