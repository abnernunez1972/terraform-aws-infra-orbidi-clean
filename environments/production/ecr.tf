resource "aws_ecr_repository" "fastapi_repo" {
  name = "fastapi-app-${var.environment}"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "fastapi-app-${var.environment}"
  }
}

resource "aws_ecr_repository" "django_repo" {
  name = "django-app-${var.environment}"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "django-app-${var.environment}"
  }
}

output "fastapi_ecr_url" {
  value = aws_ecr_repository.fastapi_repo.repository_url
}

output "django_ecr_url" {
  value = aws_ecr_repository.django_repo.repository_url
}
