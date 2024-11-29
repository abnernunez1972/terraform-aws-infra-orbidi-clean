# Security Group para ECS
# Define las reglas de tráfico de red para las instancias ECS.
resource "aws_security_group" "ecs" {
  name        = "${var.environment}-ecs-sg"       # Nombre del Security Group.
  description = "Security Group for ECS"         # Descripción del recurso.
  vpc_id      = var.vpc_id                        # ID de la VPC donde se asocia el recurso.

  # Reglas de entrada: Permitir tráfico HTTP desde el ALB.
  ingress {
    from_port       = 80                          # Puerto de inicio.
    to_port         = 80                          # Puerto final.
    protocol        = "tcp"                       # Protocolo TCP.
    security_groups = [var.alb_security_group_id] # Permitir tráfico desde el ALB.
  }

  # Reglas de entrada: Permitir tráfico HTTPS desde el ALB.
  ingress {
    from_port       = 443                         # Puerto de inicio.
    to_port         = 443                         # Puerto final.
    protocol        = "tcp"                       # Protocolo TCP.
    security_groups = [var.alb_security_group_id] # Permitir tráfico desde el ALB.
  }

  # Reglas de entrada: Permitir tráfico hacia el RDS.
  ingress {
    from_port       = 5432                        # Puerto de inicio (PostgreSQL).
    to_port         = 5432                        # Puerto final.
    protocol        = "tcp"                       # Protocolo TCP.
    security_groups = [var.rds_security_group_id] # Permitir tráfico hacia el RDS.
  }

  # Reglas de salida: Permitir todo el tráfico saliente.
  egress {
    from_port   = 0                               # Puerto de inicio.
    to_port     = 0                               # Puerto final.
    protocol    = "-1"                            # Permitir todos los protocolos.
    cidr_blocks = ["0.0.0.0/0"]                   # Permitir tráfico hacia cualquier dirección.
  }

  tags = {
    Name = "${var.environment}-ecs-sg"            # Etiqueta para identificar el Security Group.
  }
}

# Launch Template para instancias ECS
# Define una plantilla de lanzamiento para configurar las instancias ECS.
resource "aws_launch_template" "ecs_template" {
  name          = "${var.environment}-ecs-template" # Nombre del Launch Template.
  image_id      = "ami-0c02fb55956c7d316"           # ID de la AMI.
  instance_type = "t3.micro"                        # Tipo de instancia.

  iam_instance_profile {
    name = var.iam_instance_profile_name           # Referencia al perfil IAM pasado como variable.
  }

  network_interfaces {
    security_groups = [aws_security_group.ecs.id]  # Asocia el Security Group ECS.
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.environment}-ecs-instance"
    }
  }
}


# Auto Scaling Group para ECS
# Configura un grupo de escalado automático para las instancias ECS.
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity    = 2                          # Número deseado de instancias.
  max_size            = 5                          # Máximo número de instancias.
  min_size            = 2                          # Mínimo número de instancias.
  vpc_zone_identifier = var.private_subnets        # Subredes privadas para las instancias.

  # Asocia la plantilla de lanzamiento con el grupo de escalado.
  launch_template {
    id      = aws_launch_template.ecs_template.id  # ID de la plantilla de lanzamiento.
    version = "$Latest"                            # Última versión de la plantilla.
  }

  # Etiquetas para las instancias creadas por el grupo de escalado.
  tag {
    key                 = "Name"
    value               = "${var.environment}-ecs-asg"
    propagate_at_launch = true
  }
}

# Application Load Balancer (ALB)
# Configura un balanceador de carga para distribuir tráfico a ECS.
resource "aws_lb" "ecs_alb" {
  name               = "${var.environment}-ecs-alb" # Nombre del Load Balancer.
  internal           = false                        # Define el ALB como público.
  load_balancer_type = "application"                # Tipo de Load Balancer.
  security_groups    = [var.alb_security_group_id]  # Asocia el Security Group del ALB.
  subnets            = var.public_subnets           # Usa subredes públicas.

  tags = {
    Name = "${var.environment}-ecs-alb"             # Etiqueta para identificar el ALB.
  }
}

# Target Group para ECS
# Define un grupo de destino para el tráfico dirigido por el ALB.
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "${var.environment}-ecs-tg"         # Nombre del Target Group.
  port        = 80                                  # Puerto de destino.
  protocol    = "HTTP"                              # Protocolo HTTP.
  vpc_id      = var.vpc_id                          # ID de la VPC asociada.

  # Configuración de Health Checks.
  health_check {
    path                = "/"                       # Ruta para verificar la salud.
    interval            = 30                        # Intervalo entre verificaciones (segundos).
    timeout             = 5                         # Tiempo de espera (segundos).
    healthy_threshold   = 3                         # Umbral para considerarse saludable.
    unhealthy_threshold = 3                         # Umbral para considerarse no saludable.
  }
}

# Listener para ALB
# Configura un listener para recibir tráfico en el ALB.
resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn            # Asocia el ALB creado.
  port              = 80                            # Puerto de escucha.
  protocol          = "HTTP"                        # Protocolo HTTP.

  # Acción por defecto: Dirige el tráfico al grupo de destino.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

# Asociar Auto Scaling Group con Target Group del ALB
# Vincula el grupo de escalado con el grupo de destino del ALB.
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name # Grupo de Auto Scaling.
  lb_target_group_arn    = aws_lb_target_group.ecs_target_group.arn # Grupo de destino.
}

