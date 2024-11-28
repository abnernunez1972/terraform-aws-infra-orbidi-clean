# Outputs

# IDs de las subredes privadas
output "private_subnets" {
  description = "IDs de las subredes privadas"
  value       = module.vpc.private_subnets
}

# IDs de las subredes públicas
output "public_subnets" {
  description = "IDs de las subredes públicas"
  value       = module.vpc.public_subnets
}

# ID de la VPC
output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

# Security Group para ECS
output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

# Security Group para RDS
output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

