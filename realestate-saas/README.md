# PropWriter AI - 不動産特化 Vertical AI Writing SaaS

Claude API を活用した不動産業界向けライティングSaaS。
物件紹介文・賃貸契約書ドラフト・投資分析レポートを AI で自動生成。

## アーキテクチャ概要

```
[ユーザー]
    ↓ HTTPS
[AWS ALB / nginx Ingress]
    ├── /           → Frontend Pod (Next.js)
    ├── /api/v1     → Backend Pod (FastAPI + Claude API)
    └── /webhooks   → Backend Pod (Stripe Webhook)

[外部サービス]
  Supabase  ← ユーザー認証・DB・トークン管理
  Stripe    ← 課金 ($29〜$99/mo)
  Claude API ← テキスト生成エンジン
```

## ディレクトリ構成

```
realestate-saas/
├── k8s/
│   ├── namespace/
│   │   ├── namespace.yaml        # Namespace + ラベル
│   │   ├── configmap.yaml        # 環境変数（非機密）
│   │   └── secret.yaml.example   # Secret テンプレート ⚠️ 要設定
│   ├── backend/
│   │   ├── deployment.yaml       # FastAPI Pod (replicas: 2)
│   │   ├── service.yaml          # ClusterIP
│   │   └── hpa.yaml              # CPU/Memory ベース自動スケール
│   ├── frontend/
│   │   ├── deployment.yaml       # Next.js Pod (replicas: 2)
│   │   └── service.yaml          # ClusterIP
│   └── ingress/
│       └── ingress.yaml          # nginx Ingress (path-based routing)
├── dockerfiles/
│   ├── backend/
│   │   ├── Dockerfile            # Python 3.12 multi-stage build
│   │   └── requirements.txt
│   └── frontend/
│       └── Dockerfile            # Node.js 20 multi-stage build
├── src/
│   └── backend/
│       ├── main.py               # FastAPI アプリエントリーポイント
│       ├── config.py             # 環境変数管理 (pydantic-settings)
│       └── routers/
│           ├── generate.py       # ★ Claude API 不動産特化生成ロジック
│           ├── auth.py           # JWT 認証
│           ├── billing.py        # Stripe 課金 + Webhook
│           └── health.py         # ヘルスチェック
└── ansible/
    ├── deploy-k8s.yml            # K8s デプロイ Playbook
    └── inventory.yml.example     # インベントリテンプレート ⚠️ 要設定
```

## セットアップ手順

### 1. 前提確認
既存のインフラ（Terraform + Ansible + K8s on EC2 t3.micro × 3）が稼働していること。

### 2. Secret の作成
```bash
cp k8s/namespace/secret.yaml.example k8s/namespace/secret.yaml

# 各値を base64 エンコードして secret.yaml に記入
echo -n "sk-ant-your-key" | base64

# .gitignore に追加（必須！）
echo "k8s/namespace/secret.yaml" >> .gitignore
echo "ansible/inventory.yml" >> .gitignore
```

### 3. Ansible インベントリの設定
```bash
cp ansible/inventory.yml.example ansible/inventory.yml
# ansible/inventory.yml の bastion IP と AWS Account ID を更新
```

### 4. ConfigMap の更新
`k8s/namespace/configmap.yaml` で以下を環境に合わせて変更：
- `NEXT_PUBLIC_SUPABASE_URL`
- `CORS_ORIGINS`

### 5. ECR リポジトリの作成 & イメージプッシュ
```bash
# ECR リポジトリ作成
aws ecr create-repository --repository-name realestate-backend --region ap-northeast-1
aws ecr create-repository --repository-name realestate-frontend --region ap-northeast-1

# イメージビルド & プッシュ
export ECR_REGISTRY="$(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-northeast-1.amazonaws.com"
export IMAGE_TAG="v1.0.0"

# Backend
docker build -f dockerfiles/backend/Dockerfile -t $ECR_REGISTRY/realestate-backend:$IMAGE_TAG .
docker push $ECR_REGISTRY/realestate-backend:$IMAGE_TAG

# Frontend
docker build -f dockerfiles/frontend/Dockerfile -t $ECR_REGISTRY/realestate-frontend:$IMAGE_TAG ./src/frontend
docker push $ECR_REGISTRY/realestate-frontend:$IMAGE_TAG
```

### 6. Ansible でデプロイ
```bash
export IMAGE_TAG="v1.0.0"
ansible-playbook ansible/deploy-k8s.yml \
  -i ansible/inventory.yml \
  --extra-vars "image_tag=$IMAGE_TAG"
```

### 7. 動作確認
```bash
# Pod 状態確認
kubectl get pods -n realestate-saas

# API ヘルスチェック
kubectl port-forward svc/backend-service 8000:8000 -n realestate-saas
curl http://localhost:8000/health

# Ingress の外部 IP 確認（ELB の FQDN が表示される）
kubectl get ingress -n realestate-saas
```

## 生成できるドキュメント種別

| 種別 | エンドポイント | 説明 |
|------|---------------|------|
| 物件紹介文 | `POST /api/v1/generate/` (doc_type: property_listing) | SUUMO/アットホーム対応フォーマット |
| 賃貸契約書ドラフト | `POST /api/v1/generate/` (doc_type: rental_contract) | 借地借家法準拠 |
| 投資分析レポート | `POST /api/v1/generate/` (doc_type: investment_report) | 利回り計算・キャッシュフロー予測 |
| 問い合わせ返信文 | `POST /api/v1/generate/` (doc_type: inquiry_response) | 内覧誘導まで含む |
| 価格交渉レター | `POST /api/v1/generate/` (doc_type: negotiation_letter) | 根拠付き交渉文書 |

## プライシング

| プラン | 月額 | 月次トークン上限 |
|--------|------|----------------|
| Starter | $29 | 50,000 tokens |
| Pro | $79 | 200,000 tokens |
| Enterprise | $99 | 1,000,000 tokens |

## API リクエスト例

```bash
curl -X POST http://your-domain.com/api/v1/generate/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "doc_type": "property_listing",
    "tone": "friendly",
    "property_info": {
      "物件名": "グランドパレス渋谷",
      "所在地": "東京都渋谷区神南1-1-1",
      "最寄り駅": "渋谷駅 徒歩5分",
      "専有面積": "45.5㎡",
      "間取り": "1LDK",
      "築年数": "3年",
      "賃料": "18万円/月",
      "敷金礼金": "各1ヶ月"
    },
    "target_audience": "20代〜30代のカップル・DINKS"
  }'
```

## AWS 無料枠での注意点

- `t3.micro` (1vCPU/1GB) は無料枠対象外（t2.micro が無料枠）
  → 本番前に `main.tf` の `instance_type` を `t2.micro` に変更するか、低負荷期間は Pod のレプリカ数を1に削減
- Claude API は使用量課金（別途 Anthropic アカウントが必要）
- Stripe は本番決済まで無料

## TODO（次のステップ）

- [ ] Supabase テーブル設計（users, token_usage, documents）
- [ ] Next.js フロントエンドの実装（generate フォームUI）
- [ ] cert-manager で HTTPS 対応
- [ ] GitHub Actions CI/CD パイプライン
- [ ] Stripe Price ID を実際の値に更新
