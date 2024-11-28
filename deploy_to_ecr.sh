#!/bin/bash

# Configuración
ECR_URL="381492063986.dkr.ecr.us-east-1.amazonaws.com"
FASTAPI_DOCKERFILE="./aws-ecs-fastapi/fastapi-app/Dockerfile"
DJANGO_DOCKERFILE="./django-api/django_api/Dockerfile"
FASTAPI_CONTEXT="./aws-ecs-fastapi/fastapi-app"
DJANGO_CONTEXT="./django-api/django_api"

# Autenticación en ECR
echo ">> Autenticando con ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Función para construir, etiquetar y subir imágenes
build_and_push() {
    local service=$1
    local env=$2
    local dockerfile=$3
    local context=$4

    repo_name="${service}-${env}"
    echo ">> Construyendo y subiendo imagen Docker para ${service} (${env})..."
    
    docker build -f $dockerfile -t ${repo_name} $context
    docker tag ${repo_name} $ECR_URL/${repo_name}
    docker push $ECR_URL/${repo_name}
}

# FastAPI: development y production
build_and_push "fastapi-app" "deveplopment" $FASTAPI_DOCKERFILE $FASTAPI_CONTEXT
build_and_push "fastapi-app" "production" $FASTAPI_DOCKERFILE $FASTAPI_CONTEXT

# Django: development y production
build_and_push "django-app" "deveplopment" $DJANGO_DOCKERFILE $DJANGO_CONTEXT
build_and_push "django-app" "production" $DJANGO_DOCKERFILE $DJANGO_CONTEXT

echo ">> Proceso completado."
