"""
app/schemas/assistant_schema.py
================================
Pydantic v2 schemas for DigiSafe AI AI-assistant endpoints.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel

from app.schemas.document_schema import DocumentResponse


# ─────────────────────────────── Chat ─────────────────────────────────────────

class ChatMessageRequest(BaseModel):
    message: str
    conversation_history: list[dict] = []
    # Each dict: {"role": "user" | "assistant", "content": str}


class ChatResponse(BaseModel):
    reply: str
    message_type: str  # text | eligibility | expiry | bundle | verification
    data: Optional[dict] = None  # structured payload for special card types


# ─────────────────────────────── Eligibility ──────────────────────────────────

class SchemeResult(BaseModel):
    scheme_name: str
    description: str
    benefit: str
    level: str        # central | state
    state: str
    why_eligible: str
    apply_url: Optional[str] = None


class EligibilityResponse(BaseModel):
    eligible_schemes: list[SchemeResult]
    total: int
    checked_at: str


# ─────────────────────────────── Expiry ───────────────────────────────────────

class ExpiryAlertItem(BaseModel):
    document_id: str
    filename: str
    category: str
    expiry_date: str
    days_remaining: int
    urgency: str  # critical | warning | upcoming | expired


class ExpiryResponse(BaseModel):
    alerts: list[ExpiryAlertItem]
    critical_count: int
    warning_count: int
    upcoming_count: int
    expired_count: int = 0


# ─────────────────────────────── Bundle ───────────────────────────────────────

class BundleRequest(BaseModel):
    purpose: str  # e.g. "home loan", "passport application"


class BundleResponse(BaseModel):
    purpose: str
    found_documents: list[DocumentResponse]
    missing_document_types: list[str]
    bundle_complete: bool
    download_available: bool
