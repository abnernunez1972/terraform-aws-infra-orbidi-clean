output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "private_subnets" {
  description = "List of private subnets created"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "List of public subnets created"
  value       = aws_subnet.public[*].id
}
variable "azs" {
  description = "List of availability zones to deploy resources"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"] # Ajusta según tu región
}
