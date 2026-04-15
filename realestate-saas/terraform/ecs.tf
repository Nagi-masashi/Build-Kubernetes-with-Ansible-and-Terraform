# ────────────────────────────────────────────────
# CloudWatch Logs
# ────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/propwriter-backend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/propwriter-frontend"
  retention_in_days = 7
}

# ────────────────────────────────────────────────
# ECS クラスター
# ────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "propwriter-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"  # 無料枠節約のため無効
  }
}

# ────────────────────────────────────────────────
# バックエンド タスク定義
# ────────────────────────────────────────────────

resource "aws_ecs_task_definition" "backend" {
  family                   = "propwriter-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"   # 0.25 vCPU
  memory                   = "512"   # 512 MB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "${var.ecr_registry}/realestate-backend:latest"
    essential = true

    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]

    environment = [
      { name = "APP_ENV",          value = "production" },
      { name = "LOG_LEVEL",        value = "info" },
      { name = "ANTHROPIC_MODEL",  value = "claude-opus-4-6" },
      { name = "MAX_TOKENS",       value = "2048" },
      { name = "CORS_ORIGINS",     value = "http://${aws_lb.main.dns_name}" },
      { name = "NEXT_PUBLIC_SUPABASE_URL", value = var.supabase_url },
      { name = "PLAN_STARTER_TOKENS",    value = "50000" },
      { name = "PLAN_PRO_TOKENS",        value = "200000" },
      { name = "PLAN_ENTERPRISE_TOKENS", value = "1000000" }
    ]

    secrets = [
      { name = "ANTHROPIC_API_KEY",         valueFrom = "${aws_secretsmanager_secret.app.arn}:ANTHROPIC_API_KEY::" },
      { name = "SUPABASE_SERVICE_ROLE_KEY",  valueFrom = "${aws_secretsmanager_secret.app.arn}:SUPABASE_SERVICE_ROLE_KEY::" },
      { name = "SUPABASE_JWT_SECRET",        valueFrom = "${aws_secretsmanager_secret.app.arn}:SUPABASE_JWT_SECRET::" },
      { name = "STRIPE_SECRET_KEY",         valueFrom = "${aws_secretsmanager_secret.app.arn}:STRIPE_SECRET_KEY::" },
      { name = "STRIPE_WEBHOOK_SECRET",     valueFrom = "${aws_secretsmanager_secret.app.arn}:STRIPE_WEBHOOK_SECRET::" },
      { name = "JWT_SECRET",               valueFrom = "${aws_secretsmanager_secret.app.arn}:JWT_SECRET::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = "ap-northeast-1"
        "awslogs-stream-prefix" = "backend"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 30
    }
  }])
}

# ────────────────────────────────────────────────
# フロントエンド タスク定義
# ────────────────────────────────────────────────

resource "aws_ecs_task_definition" "frontend" {
  family                   = "propwriter-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "${var.ecr_registry}/realestate-frontend:latest"
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      { name = "NODE_ENV",                   value = "production" },
      { name = "NEXT_PUBLIC_API_URL",         value = "http://${aws_lb.main.dns_name}/api/v1" },
      { name = "NEXT_PUBLIC_APP_NAME",        value = "PropWriter AI" },
      { name = "NEXT_PUBLIC_SUPABASE_URL",      value = var.supabase_url },
      { name = "NEXT_PUBLIC_SUPABASE_ANON_KEY", value = var.supabase_anon_key }
    ]

    secrets = [
      { name = "NEXTAUTH_SECRET", valueFrom = "${aws_secretsmanager_secret.app.arn}:NEXTAUTH_SECRET::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = "ap-northeast-1"
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

# ────────────────────────────────────────────────
# Secrets Manager（K8s Secret の代替）
# ────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "app" {
  name                    = "propwriter/app-secrets"
  recovery_window_in_days = 0  # 即時削除可能（開発用）
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    ANTHROPIC_API_KEY         = var.anthropic_api_key
    SUPABASE_SERVICE_ROLE_KEY = var.supabase_service_role_key
    SUPABASE_JWT_SECRET       = var.supabase_jwt_secret
    STRIPE_SECRET_KEY         = var.stripe_secret_key
    STRIPE_WEBHOOK_SECRET     = var.stripe_webhook_secret
    JWT_SECRET                = var.jwt_secret
    NEXTAUTH_SECRET           = var.nextauth_secret
  })
}

# ────────────────────────────────────────────────
# ECS サービス
# ────────────────────────────────────────────────

resource "aws_ecs_service" "backend" {
  name            = "propwriter-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # ECS Exec 有効（デバッグ用）
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_c.id]
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = true  # ECR pull に必要（NAT GW なし構成）
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "frontend" {
  name            = "propwriter-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_c.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http]
}
