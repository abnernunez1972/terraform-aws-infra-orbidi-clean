variable "vpc_id" {
  description = "The ID of the VPC for RDS"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security Group ID for ECS"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets for RDS instances"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., production, development)"
  type        = string
}
