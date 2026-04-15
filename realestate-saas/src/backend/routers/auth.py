"""
Supabase トークン検証
Supabase の /auth/v1/user エンドポイントでトークンを検証する
（JWT デコードは使わず、Supabase API に問い合わせる方式）
"""
import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel

from config import settings

router = APIRouter()
security = HTTPBearer()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Supabase の /auth/v1/user API でトークンを検証してユーザー情報を返す。
    JWT デコードを使わないため、アルゴリズムの違いに影響されない。
    """
    token = credentials.credentials

    supabase_url = settings.NEXT_PUBLIC_SUPABASE_URL.rstrip("/")
    # 新旧両方のAPIキー形式に対応
    # 新形式: sb_publishable_... / sb_secret_...
    # 旧形式: eyJhbGci... (anon key)
    anon_key = settings.SUPABASE_SERVICE_ROLE_KEY  # service role で検証

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                f"{supabase_url}/auth/v1/user",
                headers={
                    "Authorization": f"Bearer {token}",
                    "apikey": anon_key,
                },
            )

        if resp.status_code == 200:
            user_data = resp.json()
            return {
                "user_id": user_data.get("id", ""),
                "email": user_data.get("email", ""),
                "role": user_data.get("role", "authenticated"),
                "plan": user_data.get("user_metadata", {}).get("plan", "starter"),
                "tokens_used_this_month": 0,
            }
        elif resp.status_code == 401:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="認証エラー: トークンが無効または期限切れです",
                headers={"WWW-Authenticate": "Bearer"},
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"認証エラー: Supabase 応答 {resp.status_code}",
                headers={"WWW-Authenticate": "Bearer"},
            )

    except httpx.TimeoutException:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="認証サービスへの接続がタイムアウトしました",
        )
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"認証サービスへの接続エラー: {str(e)}",
        )
