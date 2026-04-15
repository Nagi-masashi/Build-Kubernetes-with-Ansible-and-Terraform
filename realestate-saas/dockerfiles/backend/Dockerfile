# ============================
# Stage 1: builder
# ============================
FROM python:3.12-slim AS builder

WORKDIR /app

# 依存関係のみコピーしてキャッシュ活用
COPY dockerfiles/backend/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ============================
# Stage 2: production
# ============================
FROM python:3.12-slim AS production

# セキュリティ: 非rootユーザーで実行
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# builderからインストール済みパッケージをコピー
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# アプリコードをコピー
COPY --chown=appuser:appuser ./src/backend /app

USER appuser

EXPOSE 8000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
