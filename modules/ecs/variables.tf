variable "environment" {
  description = "Environment name (e.g., production, development)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC for ECS"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets for ECS instances"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnets for ALB"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security Group ID for RDS access"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security Group ID for ALB"
  type        = string
}
