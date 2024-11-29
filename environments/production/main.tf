terraform {
  backend "s3" {
    bucket         = "terraform-backend-orbidi"
    key            = "terraform/state/production/main.tfstate" # Clave única para production
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}



# Módulo para configurar la VPC
# Crea una Virtual Private Cloud con subredes públicas y privadas y tablas de ruteo necesarias.
module "vpc" {
  source      = "../../modules/vpc"
  environment = var.environment
}


# Rol IAM para ECS
resource "aws_iam_role" "ecs_role" {
  name = "ecs-role-${var.environment}"      # Nombre único basado en el ambiente.

  assume_role_policy = jsonencode({
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

# Perfil IAM para instancias de ECS
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile-${var.environment}"  # Nombre único basado en el ambiente.
  role = aws_iam_role.ecs_role.name
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
  depends_on = [aws_iam_instance_profile.ecs_instance_profile]
  source               = "../../modules/ecs"        # Ruta al módulo ECS.
  environment          = var.environment            # Ambiente (development, production, etc.).
  private_subnets      = module.vpc.private_subnets  # Subredes privadas para ECS.
  public_subnets       = module.vpc.public_subnets   # Subredes públicas para ALB.
  vpc_id               = module.vpc.vpc_id          # ID de la VPC asociada.
  rds_security_group_id = aws_security_group.rds.id # ID del Security Group de RDS.
  alb_security_group_id = aws_security_group.alb.id # ID del Security Group de ALB.
  iam_instance_profile_name = aws_iam_instance_profile.ecs_instance_profile.name # Nombre del perfil IAM
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
# Target Group para ECS
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-target-group-${var.environment}" # Nombre del Target Group.
  port        = 80                                    # Puerto del tráfico entrante.
  protocol    = "HTTP"                                # Protocolo HTTP.
  vpc_id      = module.vpc.vpc_id                     # ID de la VPC asociada.
  target_type = "ip"                                  # Cambia el tipo de destino a IP.

  # Configuración de Health Checks para ALB.
  health_check {
    path                = "/"                       # Ruta para verificar la salud.
    interval            = 30                        # Intervalo entre verificaciones (segundos).
    timeout             = 5                         # Tiempo de espera (segundos).
    healthy_threshold   = 3                         # Umbral para considerarse saludable.
    unhealthy_threshold = 3                         # Umbral para considerarse no saludable.
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


resource "aws_security_group" "bastion" {
  name        = "bastion-sg-${var.environment}"
  description = "Security Group for Bastion Host"
  vpc_id      = module.vpc.vpc_id

  # Permitir acceso SSH desde una IP específica
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # Tu IP pública, por ejemplo, "203.0.113.0/32"
  }

  # Permitir todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg-${var.environment}"
  }
}
resource "aws_instance" "bastion" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type = "t2.micro"              # Tipo de instancia
  subnet_id     = module.vpc.public_subnets[0] # Usa la primera subred pública
  key_name      = var.ssh_key_name        # Llave SSH para acceso seguro

  security_groups = [
    aws_security_group.bastion.id,       # Asocia el Security Group del bastión
  ]

  tags = {
    Name = "bastion-host-${var.environment}" # Etiqueta para identificar el bastión
  }
}
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.environment}-ecs-cluster"
}

output "ecs_cluster_id" {
  description = "ID del ECS Cluster creado"
  value       = aws_ecs_cluster.ecs_cluster.id
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

variable "fastapi_container_image" {
  default = "123456789012.dkr.ecr.us-east-1.amazonaws.com/fastapi-repo:latest"
}

variable "django_container_image" {
  default = "123456789012.dkr.ecr.us-east-1.amazonaws.com/django-repo:latest"
}

resource "aws_ecs_task_definition" "fastapi_task" {
  family                   = "fastapi-task-${var.environment}"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "fastapi-container"
      image     = var.fastapi_container_image  # URL de tu ECR
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_task_definition" "django_task" {
  family                   = "django-task-${var.environment}"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "django-container"
      image     = var.django_container_image  # URL de tu ECR
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}


resource "aws_ecs_service" "fastapi_service" {
  name            = "fastapi-service-${var.environment}"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.fastapi_task.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets         = module.vpc.private_subnets  # Cambia de var.private_subnets a module.vpc.private_subnets
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "fastapi-container"
    container_port   = 80
  }
}

resource "aws_ecs_service" "django_service" {
  name            = "django-service-${var.environment}"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.django_task.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets         = module.vpc.private_subnets  # Cambia de var.private_subnets a module.vpc.private_subnets
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "django-container"
    container_port   = 80
  }
}


