from pydantic import BaseModel
from typing import Optional


class ScanRequest(BaseModel):
    """Used when sending scan metadata alongside the image (multipart form)."""
    user_id: Optional[str] = None


class AssistantRequest(BaseModel):
    question: str
    # List of all document fields from SQLite (sent by Flutter, no re-scan needed)
    context_fields: list[dict]
    mode: str = "chat"   # "chat" | "eligibility"


class SyncRequest(BaseModel):
    """Batch of pending SQLite changes to push to Supabase."""
    operations: list[dict]   # [{table, record_id, operation, payload}]


class ShareRequest(BaseModel):
    document_id: str
    expires_in_hours: int = 48
