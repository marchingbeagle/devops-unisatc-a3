variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "devops-strapi"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "docker_image" {
  description = "Docker image URL"
  type        = string
}

variable "app_keys" {
  description = "Strapi APP_KEYS (comma-separated)"
  type        = string
  sensitive   = true
}

variable "admin_jwt_secret" {
  description = "Strapi ADMIN_JWT_SECRET"
  type        = string
  sensitive   = true
}

variable "api_token_salt" {
  description = "Strapi API_TOKEN_SALT"
  type        = string
  sensitive   = true
}

variable "transfer_token_salt" {
  description = "Strapi TRANSFER_TOKEN_SALT"
  type        = string
  sensitive   = true
}

variable "task_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory for ECS task (MB)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks (fixed at 1 for cost control)"
  type        = number
  default     = 1
}

