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

resource "aws_ecr_repository" "fastapi_repo_dev" {
  name = "fastapi-app-development"
}

resource "aws_ecr_repository" "django_repo_dev" {
  name = "django-app-development"
}

resource "aws_ecr_repository" "fastapi_repo_prod" {
  name = "fastapi-app-production"
}

resource "aws_ecr_repository" "django_repo_prod" {
  name = "django-app-production"
}

output "fastapi_repo_dev_url" {
  value = aws_ecr_repository.fastapi_repo_dev.repository_url
}

output "django_repo_dev_url" {
  value = aws_ecr_repository.django_repo_dev.repository_url
}

output "fastapi_repo_prod_url" {
  value = aws_ecr_repository.fastapi_repo_prod.repository_url
}

output "django_repo_prod_url" {
  value = aws_ecr_repository.django_repo_prod.repository_url
}
