"""
Stripe 課金 + Webhook ハンドラー
プライシング: Starter $29/mo / Pro $79/mo / Enterprise $99/mo
"""
import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from config import settings
from routers.auth import get_current_user

stripe.api_key = settings.STRIPE_SECRET_KEY

router = APIRouter()
webhook_router = APIRouter()

# Stripe Price ID（Stripe ダッシュボードで作成後に更新）
PRICE_IDS = {
    "starter":    "price_starter_id_here",    # $29/mo
    "pro":        "price_pro_id_here",         # $79/mo
    "enterprise": "price_enterprise_id_here",  # $99/mo
}


class CheckoutRequest(BaseModel):
    plan: str  # starter / pro / enterprise
    success_url: str
    cancel_url: str


@router.post("/checkout")
async def create_checkout_session(
    body: CheckoutRequest,
    current_user: dict = Depends(get_current_user),
):
    """Stripe Checkout セッションを作成"""
    price_id = PRICE_IDS.get(body.plan)
    if not price_id:
        raise HTTPException(status_code=400, detail="無効なプランです")

    try:
        session = stripe.checkout.Session.create(
            mode="subscription",
            payment_method_types=["card"],
            line_items=[{"price": price_id, "quantity": 1}],
            success_url=body.success_url + "?session_id={CHECKOUT_SESSION_ID}",
            cancel_url=body.cancel_url,
            metadata={"user_id": current_user["user_id"]},
        )
        return {"checkout_url": session.url}
    except stripe.StripeError as e:
        raise HTTPException(status_code=503, detail=f"Stripe エラー: {str(e)}")


@router.get("/portal")
async def customer_portal(current_user: dict = Depends(get_current_user)):
    """Stripe Customer Portal（プラン変更・解約）"""
    # TODO: Supabase から stripe_customer_id を取得
    customer_id = "cus_xxxx"  # Supabase から取得
    session = stripe.billing_portal.Session.create(
        customer=customer_id,
        return_url="https://your-domain.com/dashboard",
    )
    return {"portal_url": session.url}


@webhook_router.post("/stripe")
async def stripe_webhook(request: Request):
    """Stripe Webhook - サブスクリプションイベント処理"""
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
        )
    except (ValueError, stripe.SignatureVerificationError):
        raise HTTPException(status_code=400, detail="Webhook 署名検証失敗")

    # サブスクリプション有効化
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        user_id = session["metadata"].get("user_id")
        subscription_id = session.get("subscription")
        # TODO: Supabase でユーザーのプランを更新
        # supabase.table("users").update({"plan": "pro", "stripe_subscription_id": subscription_id})
        #   .eq("id", user_id).execute()

    # サブスクリプション更新
    elif event["type"] == "invoice.payment_succeeded":
        invoice = event["data"]["object"]
        # TODO: 月次トークン使用量をリセット
        pass

    # サブスクリプション失効
    elif event["type"] == "customer.subscription.deleted":
        subscription = event["data"]["object"]
        # TODO: プランを free にダウングレード
        pass

    return {"status": "ok"}
