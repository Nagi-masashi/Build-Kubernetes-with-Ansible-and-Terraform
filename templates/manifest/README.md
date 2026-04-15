# Vertical AI Writer SaaS — 実装ガイド

## アーキテクチャ概要

```
Internet
   │
   ▼
[AWS ALB Ingress]  ← SSL終端・ルーティング
   │
   ├─ your-domain.com     → [Frontend Pod × 2]  (Next.js)
   │                              │ SSE ストリーム
   └─ api.your-domain.com → [Backend Pod × 2]   (Express + Claude API)
                                  │
                              [HPA: 2〜10 Pod]
                                  │
                          [Anthropic Claude API]
                          (外部・claude-sonnet-4-20250514)
```

**なぜこの構成か？**
- Frontend と Backend を分離することで、それぞれ独立してスケール可能
- Backend は Claude API 呼び出し中（長時間）でも他リクエストを処理できる
- HPA で X (Twitter) バズ時のトラフィックスパイクに自動対応

---

## ディレクトリ構成

```
vertical-ai-saas/
├── backend/
│   ├── server.js        ← Express API サーバー（SSEストリーミング）
│   ├── claude.js        ← Claude API 呼び出し・業界別プロンプト
│   ├── middleware.js     ← バリデーション
│   ├── package.json
│   └── Dockerfile       ← マルチステージビルド（non-root実行）
├── frontend/
│   ├── page.js          ← Next.js ページ（SSEストリーム受信UI）
│   └── Dockerfile       ← Next.js マルチステージビルド
├── k8s/
│   ├── 00-namespace-secret.yaml   ← Namespace + Secret（APIキー）
│   ├── 01-backend.yaml            ← Deployment + Service + HPA
│   └── 02-frontend-ingress.yaml   ← Deployment + Service + Ingress
└── README.md
```

---

## デプロイ手順（AWS EKS）

### 1. ECR リポジトリ作成・イメージのプッシュ

```bash
# ECRリポジトリ作成
aws ecr create-repository --repository-name vertical-ai-backend --region ap-northeast-1
aws ecr create-repository --repository-name vertical-ai-frontend --region ap-northeast-1

# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com

# ビルド＆プッシュ（バックエンド）
cd backend
docker build -t vertical-ai-backend .
docker tag vertical-ai-backend:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/vertical-ai-backend:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/vertical-ai-backend:latest

# ビルド＆プッシュ（フロントエンド）
cd ../frontend
docker build \
  --build-arg NEXT_PUBLIC_API_URL=https://api.your-domain.com \
  -t vertical-ai-frontend .
docker tag vertical-ai-frontend:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/vertical-ai-frontend:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/vertical-ai-frontend:latest
```

### 2. Kubernetes Secret の作成（APIキーを安全に渡す）

```bash
# 絶対にYAMLにAPIキーをベタ書きしない！kubectlで直接作成する
kubectl create secret generic claude-secret \
  --namespace=vertical-ai \
  --from-literal=ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxx
```

### 3. マニフェストを適用

```bash
# YAMLのイメージURIを実際のECR URIに置換してから適用
kubectl apply -f k8s/00-namespace-secret.yaml
kubectl apply -f k8s/01-backend.yaml
kubectl apply -f k8s/02-frontend-ingress.yaml

# 確認
kubectl get pods -n vertical-ai
kubectl get ingress -n vertical-ai
```

### 4. ALB Ingress Controller のインストール（未インストールの場合）

```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER_NAME \
  --set serviceAccount.create=true
```

---

## ローカル開発

```bash
# バックエンド
cd backend
echo "ANTHROPIC_API_KEY=sk-ant-xxxx" > .env
npm install
npm run dev   # → http://localhost:3001

# フロントエンド（別ターミナル）
cd frontend
npm install
NEXT_PUBLIC_API_URL=http://localhost:3001 npm run dev  # → http://localhost:3000
```

---

## 収益化ロードマップ

| フェーズ | 期間   | やること                                  | 目標MRR    |
|----------|--------|-------------------------------------------|------------|
| MVP      | 1-2週  | 1業界に絞りデプロイ、無料で10人に使わせる | $0         |
| 検証     | 3-4週  | フィードバック収集、Stripe追加、$29/moプラン開始 | $500   |
| 拡大     | 2-3ヶ月| 4業界対応・Product Hunt投稿・Xバズ狙い   | $3K-10K   |
| スケール | 6ヶ月+ | SEO・API公開・エンタープライズ契約        | $10K-50K  |

**Claude APIコストの目安**（claude-sonnet-4-20250514）:
- 1リクエスト ≈ 1,000〜2,000トークン = 約$0.003〜$0.006
- $29/moユーザーが1日5回使用 = 月150回 × $0.005 = **$0.75/ユーザー**
- 粗利率 **97%+** （API代除く）

---

## セキュリティチェックリスト

- [x] APIキーを K8s Secret で管理（YAML にベタ書きしない）
- [x] non-root ユーザーでコンテナ実行
- [x] Rate limiting（20req/min/IP）
- [x] 入力バリデーション（業界・文書タイプ・文字数）
- [x] Helmet.js でセキュリティヘッダー設定
- [x] readOnlyRootFilesystem: true
- [ ] AWS Secrets Manager との統合（本番推奨）
- [ ] WAF の設定（ALB レベル）
- [ ] CORS の本番ドメイン制限（FRONTEND_URL 環境変数で設定済み）
