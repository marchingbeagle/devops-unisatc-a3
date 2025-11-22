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
  
  validation {
    condition     = length(var.docker_image) > 0
    error_message = "docker_image cannot be empty. Please provide a valid Docker image URL."
  }
}

variable "app_keys" {
  description = "Strapi APP_KEYS (comma-separated)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.app_keys) > 0
    error_message = "app_keys cannot be empty. Please provide a valid value."
  }
}

variable "admin_jwt_secret" {
  description = "Strapi ADMIN_JWT_SECRET"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.admin_jwt_secret) > 0
    error_message = "admin_jwt_secret cannot be empty. Please provide a valid value."
  }
}

variable "api_token_salt" {
  description = "Strapi API_TOKEN_SALT"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.api_token_salt) > 0
    error_message = "api_token_salt cannot be empty. Please provide a valid value."
  }
}

variable "transfer_token_salt" {
  description = "Strapi TRANSFER_TOKEN_SALT"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.transfer_token_salt) > 0
    error_message = "transfer_token_salt cannot be empty. Please provide a valid value."
  }
}

variable "jwt_secret" {
  description = "Strapi JWT_SECRET for users-permissions plugin"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.jwt_secret) > 0
    error_message = "jwt_secret cannot be empty. Please provide a valid value."
  }
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

