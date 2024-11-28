resource "aws_ecr_repository" "fastapi_repo" {
  name = "fastapi-app"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "fastapi-app"
  }
}

resource "aws_ecr_repository" "django_repo" {
  name = "django-app"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "django-app"
  }
}

output "fastapi_ecr_url" {
  value = aws_ecr_repository.fastapi_repo.repository_url
}

output "django_ecr_url" {
  value = aws_ecr_repository.django_repo.repository_url
}
