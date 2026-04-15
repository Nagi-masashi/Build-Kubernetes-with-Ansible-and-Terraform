# ────────────────────────────────────────────────
# ALB（Application Load Balancer）
# ────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "propwriter-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  tags               = { Name = "propwriter-alb" }
}

# ────────────────────────────────────────────────
# Target Groups
# ────────────────────────────────────────────────

resource "aws_lb_target_group" "backend" {
  name        = "propwriter-backend-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # Fargate は ip 指定

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
  tags = { Name = "propwriter-backend-tg" }
}

resource "aws_lb_target_group" "frontend" {
  name        = "propwriter-frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
  tags = { Name = "propwriter-frontend-tg" }
}

# ────────────────────────────────────────────────
# Listener & ルーティングルール
# ────────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # デフォルト → フロントエンド
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# /api/v1/* → バックエンド
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/v1/*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# /webhooks/* → バックエンド（Stripe Webhook）
resource "aws_lb_listener_rule" "backend_webhook" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/webhooks/*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
