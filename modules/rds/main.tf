# Security Group para RDS
# Define las reglas de tráfico de red para la instancia RDS.
resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"            # Nombre del Security Group.
  description = "Security Group for RDS"              # Descripción del recurso.
  vpc_id      = var.vpc_id                             # ID de la VPC donde se asocia el recurso.

  # Reglas de entrada: Permitir tráfico desde ECS hacia el puerto de PostgreSQL.
  ingress {
    from_port       = 5432                             # Puerto de inicio (PostgreSQL).
    to_port         = 5432                             # Puerto final.
    protocol        = "tcp"                            # Protocolo TCP.
    security_groups = [var.ecs_security_group_id]      # Permitir tráfico desde el Security Group ECS.
  }

  # Reglas de salida: Permitir todo el tráfico saliente.
  egress {
    from_port   = 0                                    # Puerto de inicio.
    to_port     = 0                                    # Puerto final.
    protocol    = "-1"                                 # Permitir todos los protocolos.
    cidr_blocks = ["0.0.0.0/0"]                        # Permitir tráfico hacia cualquier dirección.
  }

  tags = {
    Name = "${var.environment}-rds-sg"                 # Etiqueta para identificar el Security Group.
  }
}

resource "aws_db_instance" "db" {
  allocated_storage    = 20                            # Almacenamiento asignado en GB.
  engine               = "postgres"                   # Motor de la base de datos (PostgreSQL).
  engine_version       = "13.13"                      # Versión del motor PostgreSQL.
  instance_class       = "db.t3.micro"                # Tipo de instancia.
  username             = "pgadmin"                    # Nombre de usuario administrador.
  password             = "password123"                # Contraseña (modificar en producción).
  vpc_security_group_ids = [aws_security_group.rds.id] # Asocia el Security Group RDS.
  db_subnet_group_name = aws_db_subnet_group.main.name # Grupo de subred asociado.
  multi_az             = false                        # Desactiva la alta disponibilidad multi-AZ.
  skip_final_snapshot  = true                         # No crea un snapshot final al eliminar la instancia.
  
  identifier           = "terraform-${var.environment}-rds-${random_id.db_id.hex}" # Nombre único.

  tags = {
    Name = "${var.environment}-rds-instance"          # Etiqueta para identificar la instancia RDS.
  }
}

resource "random_id" "db_id" {
  byte_length = 4 # Genera un ID único de 8 caracteres hexadecimales.
}


# Subnet Group para RDS
# Define un grupo de subredes para la instancia RDS en las subredes privadas.
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-rds-subnet-group"   # Nombre del grupo de subred.
  subnet_ids = var.private_subnets                     # Lista de IDs de subredes privadas.

  tags = {
    Name = "${var.environment}-rds-subnet-group"       # Etiqueta para identificar el grupo de subredes.
  }
}
