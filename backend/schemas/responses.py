from pydantic import BaseModel
from typing import Optional


class ExtractedField(BaseModel):
    label: str
    value: str
    confidence: float = 0.0
    is_copyable: bool = True


class ScanResponse(BaseModel):
    """Response from POST /scan — returned to Flutter after Gemini extraction."""
    category: str
    subcategory: Optional[str] = None
    fields: list[ExtractedField] = []
    document_date: Optional[str] = None
    expiry_date: Optional[str] = None
    confidence: float = 0.0
    raw_text: Optional[str] = None
    file_hash: str                    # SHA-256 hex digest — stored in SQLite


class AssistantResponse(BaseModel):
    answer: str
    mode: str


class SchemeMatch(BaseModel):
    scheme_name: str
    level: str                  # "Central" | "State"
    benefit: str
    apply_url: str
    match_reason: str
    eligibility_score: float    # 0.0–1.0


class EligibilityResponse(BaseModel):
    matched_schemes: list[SchemeMatch]
    summary: str


class ShareResponse(BaseModel):
    share_url: str
    expires_at: str
    token: str


class SyncResponse(BaseModel):
    synced_count: int
    failed_ids: list[str] = []
