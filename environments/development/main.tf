terraform {
  backend "s3" {
    bucket         = "terraform-backend-orbidi"
    key            = "terraform/state/deveplopment/main.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

# Llamar al módulo RDS
module "rds" {
  source                 = "../../modules/rds" # Ajusta la ruta según tu estructura de carpetas
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  private_subnets        = module.vpc.private_subnets
  ecs_security_group_id  = aws_security_group.ecs.id
}

# Módulo para configurar la VPC
module "vpc" {
  source      = "../../modules/vpc"
  environment = var.environment
}

# Rol IAM para las instancias EC2 de ECS
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.environment}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Adjuntar políticas necesarias al rol IAM para instancias
resource "aws_iam_role_policy_attachment" "ecs_instance_ecs_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ecr_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Crear perfil de instancia para asociar el rol
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Rol IAM para tareas ECS
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Adjuntar política necesaria al rol para tareas ECS
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "alb-sg-${var.environment}"
  description = "Security Group for ALB"
  vpc_id      = module.vpc.vpc_id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "ecs-sg-${var.environment}"
  description = "Security Group for ECS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.environment}-ecs-cluster"
}

# Application Load Balancer
resource "aws_lb" "ecs_alb" {
  name               = "${var.environment}-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
}

# Target Group
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "${var.environment}-ecs-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Listener para ALB
resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

# Launch Template para ECS
resource "aws_launch_template" "ecs_template" {
  name          = "${var.environment}-ecs-template"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux ECS-Optimized AMI
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name}" > /etc/ecs/ecs.config
    systemctl start ecs
  EOT
  )

  network_interfaces {
    security_groups = [aws_security_group.ecs.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.environment}-ecs-instance"
    }
  }
}

# Auto Scaling Group para ECS
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = module.vpc.private_subnets

  launch_template {
    id      = aws_launch_template.ecs_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-ecs-asg"
    propagate_at_launch = true
  }
}



variable "fastapi_container_image" {
  description = "Image URI for the FastAPI container"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/fastapi-repo:latest"
}

variable "django_container_image" {
  description = "Image URI for the Django container"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/django-repo:latest"
}
resource "aws_security_group" "rds" {
  name        = "rds-sg-${var.environment}"
  description = "Security Group for RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg-${var.environment}"
  }
}


# Task Definitions
resource "aws_ecs_task_definition" "fastapi_task" {
  family                   = "fastapi-task-${var.environment}"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "fastapi-container"
    image     = var.fastapi_container_image
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
  }])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_task_definition" "django_task" {
  family                   = "django-task-${var.environment}"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "django-container"
    image     = var.django_container_image
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
  }])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

# ECS Services
resource "aws_ecs_service" "fastapi_service" {
  name            = "fastapi-service-${var.environment}"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.fastapi_task.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets         = module.vpc.private_subnets
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
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "django-container"
    container_port   = 80
  }
}
# Security Group para Bastion Host
resource "aws_security_group" "bastion" {
  name        = "bastion-sg-${var.environment}"
  description = "Security Group for Bastion Host"
  vpc_id      = module.vpc.vpc_id

  # Permitir acceso SSH desde una IP específica
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # Cambia a tu IP pública, por ejemplo, "203.0.113.0/32"
  }

  # Permitir acceso al RDS desde el bastion
  ingress {
    from_port   = 5432 # Cambia a 3306 si usas MySQL
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Ajusta según tu rango de VPC
  }

  # Permitir tráfico saliente
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

# Instancia EC2 para Bastion Host
resource "aws_instance" "bastion" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type = "t3.micro"              # Tipo de instancia
  subnet_id     = module.vpc.public_subnets[0] # Colocar en una subred pública
  key_name      = var.ssh_key_name        # Llave SSH para acceso seguro

  # Asociar el Security Group creado
  security_groups = [
    aws_security_group.bastion.id,
  ]

  # Configuración para identificar la instancia
  tags = {
    Name = "bastion-host-${var.environment}"
  }
}

# Output para conexión SSH
output "bastion_ssh_connection" {
  value = "ssh -i /path/to/key.pem ec2-user@${aws_instance.bastion.public_ip}"
  description = "Comando SSH para conectar al Bastion Host"
}

# Output de la IP pública del Bastion Host
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
  description = "IP pública del Bastion Host"
}






