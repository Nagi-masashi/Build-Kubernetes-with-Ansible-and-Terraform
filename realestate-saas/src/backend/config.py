from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    APP_ENV: str = "development"
    LOG_LEVEL: str = "info"

    # Anthropic
    ANTHROPIC_API_KEY: str
    ANTHROPIC_MODEL: str = "claude-opus-4-6"
    MAX_TOKENS: int = 2048

    # Supabase
    NEXT_PUBLIC_SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str  # Secret key (sb_secret_... or eyJhbGci...)
    SUPABASE_JWT_SECRET: str = ""   # 任意: JWT Keys セクションのシークレット

    # Stripe
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""

    # JWT (legacy)
    JWT_SECRET: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24h

    # CORS
    CORS_ORIGINS: str = "http://localhost:3000"

    # プラン別トークン上限 (月次)
    PLAN_STARTER_TOKENS: int = 50000
    PLAN_PRO_TOKENS: int = 200000
    PLAN_ENTERPRISE_TOKENS: int = 1000000

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
