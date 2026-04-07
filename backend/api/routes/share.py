from fastapi import APIRouter, Depends, HTTPException
from core.security import get_current_user_id
from schemas.requests import ShareRequest
from schemas.responses import ShareResponse
from services.share_link_service import ShareLinkService

router = APIRouter()
svc = ShareLinkService()


@router.post("", response_model=ShareResponse)
async def create_share_link(
    request: ShareRequest,
    user_id: str = Depends(get_current_user_id),
):
    """POST /share — Generate a time-limited signed URL for a document."""
    result = await svc.create_link(
        document_id=request.document_id,
        user_id=user_id,
        expires_in_hours=request.expires_in_hours,
    )
    return result


@router.delete("/{token}")
async def revoke_share_link(
    token: str,
    user_id: str = Depends(get_current_user_id),
):
    """DELETE /share/{token} — Revoke a previously issued share link."""
    await svc.revoke(token=token, user_id=user_id)
    return {"status": "revoked"}
