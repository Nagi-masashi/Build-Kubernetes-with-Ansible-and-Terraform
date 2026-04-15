#!/usr/bin/env bash
# PropWriter AI — ECR push & ECS redeploy script
# Usage: ./scripts/deploy.sh [frontend|backend|all]
set -euo pipefail

ECR_REGISTRY="468923492325.dkr.ecr.ap-northeast-1.amazonaws.com"
REGION="ap-northeast-1"
TARGET="${1:-all}"

# ── Supabase パブリック設定 ────────────────────────────
# terraform.tfvars に記載した値を貼り付けてください
SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "❌ 環境変数が未設定です。以下を設定してから実行してください:"
  echo "   export NEXT_PUBLIC_SUPABASE_URL='https://xxxx.supabase.co'"
  echo "   export NEXT_PUBLIC_SUPABASE_ANON_KEY='eyJhbGci...'"
  exit 1
fi

echo "🔐 ECR ログイン..."
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

build_push_frontend() {
  local IMAGE="${ECR_REGISTRY}/realestate-frontend:latest"
  echo ""
  echo "🔨 frontend をビルド中..."
  # ビルドコンテキスト = src/frontend（Dockerfile も src/frontend 内のファイルのみ参照）
  docker build \
    --platform linux/amd64 \
    -f dockerfiles/frontend/Dockerfile \
    --build-arg NEXT_PUBLIC_SUPABASE_URL="$SUPABASE_URL" \
    --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    -t "$IMAGE" \
    src/frontend
  echo "📤 frontend を ECR にプッシュ..."
  docker push "$IMAGE"
  echo "✅ frontend プッシュ完了: $IMAGE"
}

build_push_backend() {
  local IMAGE="${ECR_REGISTRY}/realestate-backend:latest"
  echo ""
  echo "🔨 backend をビルド中..."
  # ビルドコンテキスト = .（realestate-saas/）
  # Dockerfile が dockerfiles/backend/requirements.txt と src/backend/ を参照するため
  docker build \
    --platform linux/amd64 \
    -f dockerfiles/backend/Dockerfile \
    -t "$IMAGE" \
    .
  echo "📤 backend を ECR にプッシュ..."
  docker push "$IMAGE"
  echo "✅ backend プッシュ完了: $IMAGE"
}

force_deploy() {
  local SERVICE=$1
  echo "🚀 ECS サービス propwriter-${SERVICE} を強制更新..."
  aws ecs update-service \
    --cluster propwriter-cluster \
    --service "propwriter-${SERVICE}" \
    --force-new-deployment \
    --region $REGION \
    --output text \
    --query 'service.serviceName'
  echo "✅ propwriter-${SERVICE} のデプロイ開始"
}

# スクリプトのディレクトリから realestate-saas/ に移動
cd "$(dirname "$0")/.."

case $TARGET in
  frontend)
    build_push_frontend
    force_deploy frontend
    ;;
  backend)
    build_push_backend
    force_deploy backend
    ;;
  all)
    build_push_frontend
    build_push_backend
    force_deploy frontend
    force_deploy backend
    ;;
  *)
    echo "Usage: $0 [frontend|backend|all]"
    exit 1
    ;;
esac

echo ""
echo "🎉 デプロイ完了！"
echo "📡 ALB URL: http://propwriter-alb-2045529948.ap-northeast-1.elb.amazonaws.com"
echo "⏳ ECS タスクの起動まで約2〜3分かかります"
