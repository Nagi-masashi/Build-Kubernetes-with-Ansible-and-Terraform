variable "ecr_registry" {
  description = "ECR レジストリ URL（例: 123456789.dkr.ecr.ap-northeast-1.amazonaws.com）"
  type        = string
}

variable "supabase_url" {
  description = "Supabase プロジェクト URL"
  type        = string
}

variable "anthropic_api_key" {
  description = "Anthropic API キー"
  type        = string
  sensitive   = true
}

variable "supabase_service_role_key" {
  description = "Supabase service_role キー"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe シークレットキー"
  type        = string
  sensitive   = true
  default     = "sk_test_dummy"
}

variable "stripe_webhook_secret" {
  description = "Stripe Webhook シークレット"
  type        = string
  sensitive   = true
  default     = "whsec_dummy"
}

variable "jwt_secret" {
  description = "JWT 署名シークレット（32文字以上）"
  type        = string
  sensitive   = true
}

variable "nextauth_secret" {
  description = "NextAuth シークレット"
  type        = string
  sensitive   = true
}

variable "supabase_anon_key" {
  description = "Supabase anon (public) キー"
  type        = string
  sensitive   = true
}

variable "supabase_jwt_secret" {
  description = "Supabase JWT シークレット (Project Settings > API > JWT Settings > JWT Secret)"
  type        = string
  sensitive   = true
}
