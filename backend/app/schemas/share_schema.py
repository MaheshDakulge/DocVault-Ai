"""
app/schemas/share_schema.py
============================
Pydantic v2 schemas for DigiSafe AI document-sharing endpoints.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel

from app.schemas.document_schema import DocumentResponse


class ShareLinkCreate(BaseModel):
    document_id: str
    expires_hours: int = 24
    password: Optional[str] = None


class ShareLinkResponse(BaseModel):
    id: str
    token: str
    document_id: str
    expires_at: str
    is_active: bool
    share_url: str   # full URL, e.g. https://api.digisafe.app/share/{token}
    created_at: str


class SharedDocumentResponse(BaseModel):
    document: DocumentResponse
    shared_by: str        # name of the user who created the link
    expires_at: str
    is_password_protected: bool
