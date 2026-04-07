from fastapi import APIRouter, Depends
from core.security import get_current_user_id
from schemas.requests import SyncRequest
from schemas.responses import SyncResponse
from services.supabase_admin import SupabaseAdminService

router = APIRouter()
db = SupabaseAdminService()


@router.post("", response_model=SyncResponse)
async def sync_changes(
    request: SyncRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    POST /sync
    Accepts a batch of pending SQLite operations and upserts them into Supabase.
    Implements device-wins conflict resolution (device edits override cloud).
    """
    return await db.sync_batch(user_id=user_id, operations=request.operations)
