terraform {
  backend "s3" {
    bucket         = "terraform-backend-orbidi"       # Nombre del bucket S3 que creaste
    key            = "terraform/state/main.tfstate"   # Ruta del archivo de estado en el bucket
    region         = "us-east-1"                     # Región donde se encuentra el bucket
    dynamodb_table = "terraform-lock-table"          # Nombre de la tabla DynamoDB que creaste
    encrypt        = true                            # Habilitar encriptación para el estado
  }
}

# Módulo para configurar la VPC
# Crea una Virtual Private Cloud con subredes públicas y privadas y tablas de ruteo necesarias.
module "vpc" {
  source      = "../../modules/vpc" # Ruta al módulo que define la configuración de la VPC.
  environment = var.environment  # Se pasa desde el main.tf
}

# Perfil IAM para instancias de ECS
# Define un perfil de instancia para roles necesarios en ECS.
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceRole"                  # Nombre del perfil de instancia.
  role = aws_iam_role.ecs_role.name         # Asocia el perfil con un rol específico.
}

# Rol IAM para ECS
# Permite que las instancias ECS asuman este rol para obtener permisos.
resource "aws_iam_role" "ecs_role" {
  name = "ecs-role"                         # Nombre del rol IAM.

  assume_role_policy = jsonencode({         # Política que permite a EC2 asumir este rol.
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Security Group para ALB
# Controla el tráfico de entrada y salida del Application Load Balancer.
resource "aws_security_group" "alb" {
  name        = "alb-sg-${var.environment}" # Nombre del Security Group.
  description = "Security Group for ALB"
  vpc_id      = module.vpc.vpc_id           # ID de la VPC asociada.

  # Reglas de entrada: Permite tráfico HTTP y HTTPS desde cualquier origen.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Reglas de salida: Permite tráfico de cualquier puerto y protocolo.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg-${var.environment}"      # Etiqueta para identificar el Security Group.
  }
}

# Security Group para ECS
# Controla el tráfico de entrada y salida para las instancias de ECS.
resource "aws_security_group" "ecs" {
  name        = "ecs-sg-${var.environment}" # Nombre del Security Group.
  description = "Security Group for ECS"
  vpc_id      = module.vpc.vpc_id           # ID de la VPC asociada.

  # Reglas de entrada: Permite tráfico HTTP y HTTPS desde cualquier origen.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Reglas de salida: Permite tráfico de cualquier puerto y protocolo.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg-${var.environment}"      # Etiqueta para identificar el Security Group.
  }
}

# Security Group para RDS
# Controla el tráfico de entrada y salida para la base de datos RDS.
resource "aws_security_group" "rds" {
  name        = "rds-sg-${var.environment}" # Nombre del Security Group.
  description = "Security Group for RDS"
  vpc_id      = module.vpc.vpc_id           # ID de la VPC asociada.

  # Reglas de entrada: Permite tráfico desde las instancias ECS al puerto de RDS (5432).
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Reglas de salida: Permite tráfico de cualquier puerto y protocolo.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg-${var.environment}"      # Etiqueta para identificar el Security Group.
  }
}

# Módulo ECS
# Configura la infraestructura ECS con Auto Scaling y vinculaciones con ALB y RDS.
module "ecs" {
  source               = "../../modules/ecs"        # Ruta al módulo ECS.
  environment          = var.environment  # Se pasa desde el main.tf
  private_subnets      = module.vpc.private_subnets # Subredes privadas para ECS.
  public_subnets       = module.vpc.public_subnets  # Subredes públicas para ALB.
  vpc_id               = module.vpc.vpc_id          # ID de la VPC asociada.
  rds_security_group_id = aws_security_group.rds.id # ID del Security Group de RDS.
  alb_security_group_id = aws_security_group.alb.id # ID del Security Group de ALB.
}

# Módulo RDS
# Configura la base de datos relacional en subredes privadas.
module "rds" {
  source               = "../../modules/rds"        # Ruta al módulo RDS.
  private_subnets      = module.vpc.private_subnets # Subredes privadas para RDS.
  vpc_id               = module.vpc.vpc_id          # ID de la VPC asociada.
  ecs_security_group_id = aws_security_group.ecs.id # ID del Security Group de ECS.
  environment          = var.environment  # Se pasa desde el main.tf
}

# Application Load Balancer (ALB)
# Distribuye tráfico entrante a las instancias ECS en subredes públicas.
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb-${var.environment}" # Nombre del Load Balancer.
  internal           = false                        # Indica que el ALB es público.
  load_balancer_type = "application"                # Tipo de Load Balancer.
  security_groups    = [aws_security_group.alb.id]  # Asocia el Security Group de ALB.
  subnets            = module.vpc.public_subnets    # Usa subredes públicas.

  tags = {
    Name = "ecs-alb-${var.environment}"             # Etiqueta para identificar el ALB.
  }
}

# Target Group para ALB
# Define el grupo de destino para el ALB, asociándolo con ECS.
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-target-group-${var.environment}" # Nombre del Target Group.
  port        = 80                                    # Puerto del tráfico entrante.
  protocol    = "HTTP"                                # Protocolo HTTP.
  vpc_id      = module.vpc.vpc_id                     # ID de la VPC asociada.

  # Configuración de Health Checks para ALB.
  health_check {
    path                = "/"  # Ruta para verificar la salud.
    interval            = 30   # Intervalo entre verificaciones (segundos).
    timeout             = 5    # Tiempo de espera (segundos).
    healthy_threshold   = 3    # Umbral para considerarse saludable.
    unhealthy_threshold = 3    # Umbral para considerarse no saludable.
  }
}

# Listener para ALB
# Configura el Listener para dirigir tráfico al grupo de destino.
resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn             # Asocia el ALB creado.
  port              = 80                             # Puerto de escucha.
  protocol          = "HTTP"                         # Protocolo HTTP.

  # Acción por defecto: Dirige el tráfico al grupo de destino.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

# Auto Scaling Attachment
# Vincula el grupo de Auto Scaling con el grupo de destino del ALB.
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = module.ecs.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.ecs_target_group.arn
}
