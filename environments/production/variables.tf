variable "environment" {
  description = "The environment name"
  type        = string
  default     = "production"
}

variable "ssh_key_name" {
  description = "Nombre de la llave SSH para acceder al bastión"
  type        = string
  default     = "" # Valor predeterminado vacío, lo que permite omitir esta variable
}

variable "my_ip_cidr" {
  description = "Tu IP pública desde la cual permitir acceso SSH"
  type        = string
  default     = "0.0.0.0/0" # Permitir acceso desde cualquier IP por defecto (no recomendado en producción)
}
variable "iam_instance_profile_name" {
  description = "Nombre del perfil IAM asociado a las instancias"
  default     = "ecsInstanceRole"
  type        = string
}