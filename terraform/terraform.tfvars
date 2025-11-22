# Terraform variables for local testing
# Generated automatically - DO NOT commit this file to Git!

# AWS Configuration
aws_region = "sa-east-1"

# Application Configuration
app_name     = "devops-strapi"
environment  = "production"

# Docker Image (update with your actual image)
docker_image = "your-dockerhub-username/devops-strapi:latest"

# Strapi Secrets (generated automatically)
app_keys            = "yG6Y1BRwkstw8oAABtkBk2q5CuLHRJlEfx7fGLAy1Iw=,G044+L5aJcl3wpap5MH2y74qUV4J30aPH3y5JuNYWro=,1fjMJLwaw8lDnODJDXe07l0vGMQbqpU7TLqi6FOtxY8=,byV10TeYifs1uJtlwhD8JuQD74Il2t0hKs8vE/fESRc="
admin_jwt_secret    = "t6iKK+lH10CjnXX+M/yRhVbCXjQPASTwXtvAKMsCBDU="
api_token_salt      = "oDb5UtBC6RE7AiM8NiVgNDEGk5pYKCqqR05HOVG107c="
transfer_token_salt = "O+EaUbQRhsuRpFXqVdnzx6+daGE6E4hzvHHhfSqozXE="

# ECS Task Configuration
task_cpu     = 512
task_memory  = 1024
desired_count = 1
