"""
app/schemas/scan_schema.py
==========================
Pydantic v2 schemas for DigiSafe AI scan endpoints.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel

from app.schemas.document_schema import FieldItem


# ─────────────────────────────── Job status ───────────────────────────────────

class ScanJobResponse(BaseModel):
    job_id: str
    status: str          # queued | processing | done | failed
    step: int = 0
    progress_pct: float = 0
    document_id: Optional[str] = None
    error_message: Optional[str] = None


# ─────────────────────────────── Scan result ──────────────────────────────────

class ScanResultResponse(BaseModel):
    job_id: str
    document_id: Optional[str] = None
    category: str
    subcategory: Optional[str] = None
    doc_type: str
    document_date: Optional[str] = None
    expiry_date: Optional[str] = None
    owner_name: Optional[str] = None
    confidence: float
    is_duplicate: bool = False
    duplicate_of: Optional[str] = None
    is_tampered_suspected: bool = False
    fields: list[FieldItem] = []


# ─────────────────────────────── Confirm request ──────────────────────────────

class ScanConfirmRequest(BaseModel):
    job_id: str
    category: Optional[str] = None          # user can override Gemini's category
    fields: Optional[list[FieldItem]] = None # user can edit/approve fields
