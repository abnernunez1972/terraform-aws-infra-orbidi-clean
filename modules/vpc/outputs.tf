output "private_subnets" {
  description = "IDs de las subredes privadas creadas"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "IDs de las subredes públicas creadas"
  value       = aws_subnet.public[*].id
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

variable "azs" {
  description = "List of availability zones to deploy resources"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"] # Ajusta según tu región
}
