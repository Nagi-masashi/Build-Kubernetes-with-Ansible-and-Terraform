"""
WriteAI — 汎用 AI コンテンツ生成ルーター
不動産・EC・飲食・採用・法律・医療・カスタムに対応
"""
import anthropic
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings
from routers.auth import get_current_user

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)
client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)


# ────────────────────────────────────────────────
# スキーマ
# ────────────────────────────────────────────────

class GenerateRequest(BaseModel):
    content_type:  str
    genre:         str = "real_estate"
    tone:          str = "formal"
    company_name:  str = ""
    property_details: dict = Field(default_factory=dict, description="フォーム入力値")


class GenerateResponse(BaseModel):
    content:          str
    content_type:     str
    genre:            str
    tokens_used:      int
    remaining_tokens: int


# ────────────────────────────────────────────────
# システムプロンプト定義（ジャンル × コンテンツタイプ）
# ────────────────────────────────────────────────

SYSTEM_PROMPTS: dict[str, dict[str, str]] = {

    "real_estate": {
        "property_description": """あなたは日本の不動産業界に精通したプロのコピーライターです。
宅地建物取引業法・景品表示法に準拠し、SUUMO/アットホームの標準フォーマットで
SEO最適化された魅力的な物件説明文を作成します。
見出し・物件概要テーブル・説明文・アピールポイントの構成で出力してください。""",

        "investment_analysis": """あなたは不動産投資に精通したアナリストです。
表面利回り・実質利回り・キャッシュフロー予測（5年・10年）・リスク要因・投資判断サマリーを含む
詳細な投資分析レポートを作成します。""",

        "neighborhood_guide": """あなたは地域情報に詳しい不動産エージェントです。
交通アクセス・生活利便施設・教育環境・街の雰囲気・治安・将来性を含む
購入検討者向けの周辺環境ガイドを作成します。""",

        "negotiation_script": """あなたは不動産取引の交渉経験豊富な専門家です。
買主・売主それぞれのトークスクリプト、想定される反論と切り返し、
着地点への誘導テクニックを含む実践的な交渉スクリプトを作成します。""",

        "market_report": """あなたは不動産市場調査の専門アナリストです。
対象エリアの価格水準・トレンド・供需バランス・今後の見通しを含む
詳細なマーケットレポートを作成します。""",
    },

    "ecommerce": {
        "product_description": """あなたはEC業界のプロのコピーライターです。
購買意欲を最大化するため、商品の特徴・ベネフィット・差別化ポイントを
読者の感情に訴える形で商品説明文を作成します。
キャッチコピー・特徴箇条書き・詳細説明・購入を後押しするCTAの構成で出力してください。""",

        "ad_copy": """あなたはデジタル広告のスペシャリストです。
SNS・バナー・リスティング広告向けに、クリック率と購買率を高める
短く刺さる広告コピーを複数パターン作成します。""",

        "review_response": """あなたはカスタマーサクセスの専門家です。
顧客のレビューに対して、感謝・共感・問題解決・ブランドイメージ向上を意識した
丁寧かつ自然な返信文を作成します。""",

        "email_campaign": """あなたはメールマーケティングの専門家です。
開封率・クリック率・コンバージョン率を高めるメールマガジンを
件名・プレヘッダー・本文・CTA の構成で作成します。""",

        "lp_copy": """あなたはランディングページ最適化の専門家です。
ヒーローコピー・課題提起・解決策・社会的証明・CTA の構成で
コンバージョン率を最大化するLPコピーを作成します。""",
    },

    "restaurant": {
        "menu_description": """あなたは食の専門ライターです。
食材・調理法・味・食感・見た目の魅力を五感に訴える言葉で表現し、
注文したくなるメニュー説明文を作成します。""",

        "review_response": """あなたは飲食店のPRマネージャーです。
口コミに対して、感謝・誠実さ・再来店を促す要素を盛り込んだ
自然で温かみのある返信文を作成します（200字程度）。""",

        "sns_post": """あなたは飲食店のSNSマーケターです。
Instagram・X向けに、食欲をそそりシェアされやすい投稿文を
ハッシュタグ候補付きで作成します。""",

        "news_letter": """あなたは飲食店のPR担当者です。
新メニュー・イベント・季節のお知らせを顧客に魅力的に伝える
メールやチラシ向けのお知らせ文を作成します。""",

        "concept": """あなたは飲食店ブランディングの専門家です。
店の想い・コンセプト・こだわりを感動的に伝える
採用サイト・公式サイト向けのコンセプト文を作成します。""",
    },

    "recruitment": {
        "job_posting": """あなたは採用マーケティングの専門家です。
応募者の心を掴む求人票を、仕事内容・魅力・求める人物像・待遇・
応募へのCTAの構成で作成します。リクナビ・マイナビ・Wantedly 向けのフォーマットで。""",

        "interview_questions": """あなたは採用のプロフェッショナルです。
候補者の能力・カルチャーフィット・価値観を見極める
効果的な面接質問リストを評価ポイント付きで作成します。""",

        "offer_letter": """あなたは人事のスペシャリストです。
候補者に入社を決意させる、温かみのある内定通知・オファーレターを
条件明示・入社への期待・次のステップを含めて作成します。""",

        "company_profile": """あなたは採用ブランディングの専門家です。
優秀な人材を惹きつける会社紹介文を、ミッション・カルチャー・
チーム・成長機会・福利厚生を盛り込んで作成します。""",

        "rejection_email": """あなたは人事担当者です。
候補者の尊厳を守り、会社のブランドを傷つけない
丁寧で誠実な不採用通知メールを作成します。""",
    },

    "legal": {
        "contract_draft": """あなたは日本法に精通した法務専門家です。
依頼された契約書の初稿ドラフトを民法・関連法規に準拠して作成します。
※このドラフトは参考用です。最終的には弁護士の確認を推奨します。""",

        "legal_opinion": """あなたは法律の専門家です。
提示された法的論点を整理し、関連法規・判例・リスク・推奨対応を含む
実務的な法律意見書を作成します。""",

        "demand_letter": """あなたは法律の専門家です。
相手方への法的通知・内容証明郵便の文案を
法的根拠・要求事項・期限を明確にして作成します。""",

        "privacy_policy": """あなたはプライバシー法の専門家です。
個人情報保護法・GDPRに準拠した
Webサービス向けのプライバシーポリシーを作成します。""",

        "terms_of_service": """あなたはIT法務の専門家です。
サービスの利用規約・約款を
利用者・運営者双方を適切に保護する形で作成します。""",
    },

    "medical": {
        "patient_explanation": """あなたは医療コミュニケーションの専門家です。
専門用語を使わず、患者が理解・安心できる
分かりやすい病気・治療・薬の説明文を作成します。""",

        "clinic_news": """あなたはクリニックの広報担当者です。
患者に必要な情報を分かりやすく伝える
休診・新サービス・健康情報のお知らせ文を作成します。""",

        "health_column": """あなたは医療ライターです。
一般読者が健康を理解・実践できる
正確でわかりやすい健康コラムを作成します。
医学的な根拠に基づき、過度な恐怖を煽らない表現を使います。""",

        "faq": """あなたは医療広報の専門家です。
患者がよく持つ疑問に対して、専門用語を避けた
Q&A形式の分かりやすい回答を作成します。""",

        "referral_letter": """あなたは医師です。
他院への患者紹介状を、紹介理由・経緯・現状・依頼事項を含む
適切な医療文書として作成します。""",
    },

    "custom": {
        "custom_1": "あなたは優秀なライターです。ユーザーが提供する情報を元に、高品質な文章を作成します。",
        "custom_2": "あなたは優秀なライターです。ユーザーが提供する情報を元に、高品質な文章を作成します。",
        "custom_3": "あなたは優秀なライターです。ユーザーが提供する情報を元に、高品質な文章を作成します。",
    },
}

TONE_INSTRUCTIONS = {
    "formal":     "文体は丁寧・フォーマルなビジネス文書調で。",
    "friendly":   "文体は親しみやすく、読みやすい日常語で。",
    "persuasive": "文体は説得力を重視し、感情に訴えるコピーライティング調で。",
    "simple":     "文体はシンプル・簡潔に。余計な言葉は省く。",
}


def build_prompt(req: GenerateRequest) -> str:
    lines = []
    if req.company_name:
        lines.append(f"【依頼者情報】\n- 会社名・屋号: {req.company_name}")
    lines.append("【入力情報】")
    for k, v in req.property_details.items():
        if v:
            lines.append(f"- {k}: {v}")
    tone_instr = TONE_INSTRUCTIONS.get(req.tone, "")
    if tone_instr:
        lines.append(f"\n【文体指定】\n{tone_instr}")
    lines.append("\n上記の情報をもとに高品質な文章を作成してください。")
    return "\n".join(lines)


# ────────────────────────────────────────────────
# エンドポイント
# ────────────────────────────────────────────────

@router.post("/", response_model=GenerateResponse)
@limiter.limit("20/minute")
async def generate_document(
    request: Request,
    body: GenerateRequest,
    current_user: dict = Depends(get_current_user),
):
    remaining = _get_remaining_tokens(current_user)
    if remaining <= 0:
        raise HTTPException(status_code=402, detail="月次トークン上限に達しました。プランをアップグレードしてください。")

    genre_prompts = SYSTEM_PROMPTS.get(body.genre, SYSTEM_PROMPTS["custom"])
    system_prompt = genre_prompts.get(body.content_type, list(genre_prompts.values())[0])
    user_prompt = build_prompt(body)

    try:
        message = client.messages.create(
            model=settings.ANTHROPIC_MODEL,
            max_tokens=settings.MAX_TOKENS,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )
    except anthropic.APIError as e:
        raise HTTPException(status_code=503, detail=f"AI生成エラー: {str(e)}")

    tokens_used = message.usage.input_tokens + message.usage.output_tokens
    _deduct_tokens(current_user["user_id"], tokens_used)

    return GenerateResponse(
        content=message.content[0].text,
        content_type=body.content_type,
        genre=body.genre,
        tokens_used=tokens_used,
        remaining_tokens=max(0, remaining - tokens_used),
    )


def _get_remaining_tokens(user: dict) -> int:
    plan = user.get("plan", "starter")
    limits = {
        "starter":    settings.PLAN_STARTER_TOKENS,
        "pro":        settings.PLAN_PRO_TOKENS,
        "enterprise": settings.PLAN_ENTERPRISE_TOKENS,
    }
    return limits.get(plan, settings.PLAN_STARTER_TOKENS) - user.get("tokens_used_this_month", 0)


def _deduct_tokens(user_id: str, tokens: int):
    pass  # TODO: Supabase RPC
