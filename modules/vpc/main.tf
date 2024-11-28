# Define la VPC
# Crea una VPC para alojar toda la infraestructura de red.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"             # Rango de direcciones IP para la VPC.
  enable_dns_support   = true                      # Habilita la resolución DNS dentro de la VPC.
  enable_dns_hostnames = true                      # Habilita los nombres DNS asignados automáticamente.

  tags = {
    Name = "${var.environment}-vpc"               # Etiqueta para identificar la VPC.
  }
}

# Subnets públicas
# Crea subredes públicas en cada zona de disponibilidad especificada.
resource "aws_subnet" "public" {
  count                   = length(var.azs)       # Número de subredes basado en las zonas de disponibilidad (AZs).
  vpc_id                  = aws_vpc.main.id       # ID de la VPC a la que pertenece la subred.
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # Divide el rango CIDR de la VPC.
  availability_zone       = element(var.azs, count.index) # Asigna cada subred a una AZ.
  map_public_ip_on_launch = true                  # Habilita la asignación automática de IPs públicas.

  tags = {
    Name = "${var.environment}-public-subnet-${count.index}" # Etiqueta para identificar la subred.
  }
}

# Subnets privadas
# Crea subredes privadas en cada zona de disponibilidad especificada.
resource "aws_subnet" "private" {
  count            = length(var.azs)             # Número de subredes basado en las zonas de disponibilidad (AZs).
  vpc_id           = aws_vpc.main.id             # ID de la VPC a la que pertenece la subred.
  cidr_block       = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + length(var.azs)) # Rango CIDR para subredes privadas.
  availability_zone = element(var.azs, count.index) # Asigna cada subred a una AZ.

  tags = {
    Name = "${var.environment}-private-subnet-${count.index}" # Etiqueta para identificar la subred.
  }
}

# Internet Gateway
# Proporciona acceso a Internet a las subredes públicas.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id                       # ID de la VPC asociada.

  tags = {
    Name = "${var.environment}-igw"             # Etiqueta para identificar el Internet Gateway.
  }
}

# Public Route Table
# Define una tabla de rutas públicas para dirigir el tráfico de Internet a través del Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id                       # ID de la VPC asociada.

  route {
    cidr_block = "0.0.0.0/0"                     # Permitir tráfico hacia cualquier dirección IP.
    gateway_id = aws_internet_gateway.igw.id     # Ruta a través del Internet Gateway.
  }

  tags = {
    Name = "${var.environment}-public-route-table" # Etiqueta para identificar la tabla de rutas públicas.
  }
}

# Associate Public Route Table with Public Subnets
# Asocia la tabla de rutas públicas con las subredes públicas.
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)     # Número de asociaciones basadas en el número de subredes públicas.
  subnet_id      = aws_subnet.public[count.index].id # ID de cada subred pública.
  route_table_id = aws_route_table.public.id     # ID de la tabla de rutas públicas.
}

# Private Route Table (example for NAT Gateway or VPN, optional)
# Define una tabla de rutas privadas para las subredes privadas (opcional).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id                       # ID de la VPC asociada.

  tags = {
    Name = "${var.environment}-private-route-table" # Etiqueta para identificar la tabla de rutas privadas.
  }
}

# Associate Private Route Table with Private Subnets
# Asocia la tabla de rutas privadas con las subredes privadas.
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)    # Número de asociaciones basadas en el número de subredes privadas.
  subnet_id      = aws_subnet.private[count.index].id # ID de cada subred privada.
  route_table_id = aws_route_table.private.id    # ID de la tabla de rutas privadas.
}
