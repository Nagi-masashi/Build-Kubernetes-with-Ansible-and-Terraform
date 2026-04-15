"""
PropWriter AI - 不動産特化 Claude API ラッパー
FastAPI バックエンドメイン
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from config import settings
from routers import generate, auth, billing, health

# レート制限 (IP単位)
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="PropWriter AI API",
    description="不動産業界特化 Claude API ライティングサービス",
    version="1.0.0",
    docs_url="/api/v1/docs" if settings.APP_ENV != "production" else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ルーター登録
app.include_router(health.router)
app.include_router(auth.router,     prefix="/api/v1/auth",     tags=["auth"])
app.include_router(generate.router, prefix="/api/v1/generate", tags=["generate"])
app.include_router(billing.router,  prefix="/api/v1/billing",  tags=["billing"])
app.include_router(billing.webhook_router, prefix="/webhooks", tags=["webhooks"])
