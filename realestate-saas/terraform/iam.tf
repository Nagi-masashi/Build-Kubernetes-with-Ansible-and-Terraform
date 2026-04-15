# ────────────────────────────────────────────────
# ECS タスク実行ロール（ECR pull + CloudWatch logs）
# ────────────────────────────────────────────────

resource "aws_iam_role" "ecs_task_execution" {
  name = "propwriter-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager / SSM Parameter Store から Secrets を取得する権限（任意）
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "propwriter-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "ssm:GetParameters",
        "kms:Decrypt"
      ]
      Resource = "*"
    }]
  })
}

# ────────────────────────────────────────────────
# ECS タスクロール（アプリ実行時の権限）
# ────────────────────────────────────────────────

resource "aws_iam_role" "ecs_task" {
  name = "propwriter-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ECS Exec（コンテナへのデバッグアクセス）用
resource "aws_iam_role_policy" "ecs_exec" {
  name = "propwriter-ecs-exec-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}
