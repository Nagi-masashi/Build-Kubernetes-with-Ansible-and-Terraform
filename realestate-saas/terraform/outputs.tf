output "alb_dns_name" {
  description = "ALB の DNS 名（アクセス URL）"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS クラスター名"
  value       = aws_ecs_cluster.main.name
}

output "backend_log_group" {
  description = "バックエンドの CloudWatch ロググループ"
  value       = aws_cloudwatch_log_group.backend.name
}

output "frontend_log_group" {
  description = "フロントエンドの CloudWatch ロググループ"
  value       = aws_cloudwatch_log_group.frontend.name
}
