variable "private_subnets" {
  description = "IDs de las subredes privadas"
  type        = list(string)
}

variable "public_subnets" {
  description = "IDs de las subredes públicas"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "environment" {
  description = "Ambiente (development, production, etc.)"
  type        = string
}

variable "rds_security_group_id" {
  description = "ID del Security Group de RDS"
  type        = string
}

variable "alb_security_group_id" {
  description = "ID del Security Group de ALB"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "Nombre del perfil IAM para ECS"
  type        = string
}
