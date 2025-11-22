# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  # Container Insights disabled to avoid costs (not free tier)
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "strapi" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 7

  tags = local.common_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "strapi" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "strapi"
      image = var.docker_image

      portMappings = [
        {
          containerPort = 1337
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "HOST"
          value = "0.0.0.0"
        },
        {
          name  = "PORT"
          value = "1337"
        },
        {
          name  = "DATABASE_CLIENT"
          value = "sqlite"
        },
        {
          name  = "DATABASE_FILENAME"
          value = "/tmp/data.db"
        }
      ]

      secrets = [
        {
          name      = "APP_KEYS"
          valueFrom = aws_secretsmanager_secret.app_keys.arn
        },
        {
          name      = "ADMIN_JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.admin_jwt_secret.arn
        },
        {
          name      = "API_TOKEN_SALT"
          valueFrom = aws_secretsmanager_secret.api_token_salt.arn
        },
        {
          name      = "TRANSFER_TOKEN_SALT"
          valueFrom = aws_secretsmanager_secret.transfer_token_salt.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.strapi.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:1337/admin || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# Secrets Manager secrets for Strapi configuration
resource "aws_secretsmanager_secret" "app_keys" {
  name        = "${local.name_prefix}-app-keys"
  description = "Strapi APP_KEYS"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_keys" {
  secret_id     = aws_secretsmanager_secret.app_keys.id
  secret_string = var.app_keys
}

resource "aws_secretsmanager_secret" "admin_jwt_secret" {
  name        = "${local.name_prefix}-admin-jwt-secret"
  description = "Strapi ADMIN_JWT_SECRET"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "admin_jwt_secret" {
  secret_id     = aws_secretsmanager_secret.admin_jwt_secret.id
  secret_string = var.admin_jwt_secret
}

resource "aws_secretsmanager_secret" "api_token_salt" {
  name        = "${local.name_prefix}-api-token-salt"
  description = "Strapi API_TOKEN_SALT"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "api_token_salt" {
  secret_id     = aws_secretsmanager_secret.api_token_salt.id
  secret_string = var.api_token_salt
}

resource "aws_secretsmanager_secret" "transfer_token_salt" {
  name        = "${local.name_prefix}-transfer-token-salt"
  description = "Strapi TRANSFER_TOKEN_SALT"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "transfer_token_salt" {
  secret_id     = aws_secretsmanager_secret.transfer_token_salt.id
  secret_string = var.transfer_token_salt
}

# IAM policy to allow ECS tasks to read secrets
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${local.name_prefix}-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.app_keys.arn,
          aws_secretsmanager_secret.admin_jwt_secret.arn,
          aws_secretsmanager_secret.api_token_salt.arn,
          aws_secretsmanager_secret.transfer_token_salt.arn
        ]
      }
    ]
  })
}

# ECS Service
resource "aws_ecs_service" "strapi" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  tags = local.common_tags
}

