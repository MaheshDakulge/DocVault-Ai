"""
app/schemas/document_schema.py
===============================
Pydantic v2 schemas for DigiSafe AI document endpoints.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict


# ─────────────────────────────── Sub-models ───────────────────────────────────

class FieldItem(BaseModel):
    id: Optional[str] = None
    label: str
    value: str
    confidence: float = 1.0
    is_copyable: bool = True


# ─────────────────────────────── Document ─────────────────────────────────────

class DocumentResponse(BaseModel):
    id: str
    filename: str
    storagePath: Optional[str] = None      # camelCase — matches DB column
    category: str
    subcategory: Optional[str] = None
    doc_type: Optional[str] = None
    document_date: Optional[str] = None
    expiry_date: Optional[str] = None
    owner_name: Optional[str] = None
    ocr_confidence: Optional[float] = None
    is_tampered: bool = False
    is_verified: bool = False
    importance: str = "normal"
    tags: list[str] = []
    fields: list[FieldItem] = []
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class DocumentUpdateRequest(BaseModel):
    category: Optional[str] = None
    subcategory: Optional[str] = None
    importance: Optional[str] = None
    tags: Optional[list[str]] = None
    document_date: Optional[str] = None


# ─────────────────────────────── Tree / Timeline ──────────────────────────────

class TreeCategoryResponse(BaseModel):
    category: str
    icon: str
    color: str
    count: int
    documents: list[DocumentResponse]


class TimelineYearResponse(BaseModel):
    year: int
    count: int
    documents: list[DocumentResponse]
