import secrets
from datetime import datetime, timedelta
from supabase import create_client
from core.config import settings
from schemas.responses import ShareResponse

supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class ShareLinkService:
    async def create_link(
        self, document_id: str, user_id: str, expires_in_hours: int = 48
    ) -> ShareResponse:
        token = secrets.token_urlsafe(32)
        expires_at = (datetime.utcnow() + timedelta(hours=expires_in_hours)).isoformat()

        supabase.table("shared_links").insert({
            "document_id": document_id,
            "user_id": user_id,
            "token": token,
            "expires_at": expires_at,
            "is_active": True,
        }).execute()

        share_url = f"{settings.SUPABASE_URL}/share/{token}"
        return ShareResponse(share_url=share_url, expires_at=expires_at, token=token)

    async def revoke(self, token: str, user_id: str) -> None:
        supabase.table("shared_links")\
            .update({"is_active": False})\
            .eq("token", token)\
            .eq("user_id", user_id)\
            .execute()
