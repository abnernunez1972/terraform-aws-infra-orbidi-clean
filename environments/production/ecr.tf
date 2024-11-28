resource "aws_ecr_repository" "fastapi_repo" {
  name = "fastapi-app-prodcution"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "fastapi-app-prodcution"
  }
}

resource "aws_ecr_repository" "django_repo" {
  name = "django-app-prodcution"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "django-app-prodcution"
  }
}

output "fastapi_ecr_url" {
  value = aws_ecr_repository.fastapi_repo.repository_url
}

output "django_ecr_url" {
  value = aws_ecr_repository.django_repo.repository_url
}
