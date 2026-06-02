"""
app/api/share.py
=================
Secure document sharing router for DigiSafe AI.

Endpoints:
  POST   /share/create
  GET    /share/{token}          — public, no auth
  POST   /share/{token}/verify-password — public
  DELETE /share/{link_id}
  GET    /share                  — list my links
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import uuid4

import bcrypt
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import settings
from app.core.database import get_supabase_sync
from app.core.security import get_current_user
from app.schemas.document_schema import DocumentResponse, FieldItem
from app.schemas.share_schema import (
    ShareLinkCreate,
    ShareLinkResponse,
    SharedDocumentResponse,
)
from app.services import storage_service

router = APIRouter()
logger = logging.getLogger(__name__)


def _build_share_url(token: str) -> str:
    return f"{settings.supabase_url.replace('.supabase.co', '')}/share/{token}"


def _link_to_response(link: dict) -> ShareLinkResponse:
    return ShareLinkResponse(
        id=link["id"],
        token=link["token"],
        document_id=link["document_id"],
        expires_at=str(link.get("expires_at", "")),
        is_active=bool(link.get("is_active", True)),
        share_url=_build_share_url(link["token"]),
        created_at=str(link.get("created_at", "")),
    )


def _doc_to_response(doc: dict, fields: list[FieldItem]) -> DocumentResponse:
    return DocumentResponse(
        id=doc["id"],
        filename=doc.get("filename", ""),
        storage_path=doc.get("storage_path"),
        category=doc.get("category", "Other"),
        subcategory=doc.get("subcategory"),
        doc_type=doc.get("doc_type"),
        document_date=doc.get("document_date") and str(doc["document_date"])[:10],
        expiry_date=doc.get("expiry_date") and str(doc["expiry_date"])[:10],
        owner_name=doc.get("owner_name"),
        ocr_confidence=doc.get("ocr_confidence"),
        is_tampered=bool(doc.get("is_tampered", False)),
        is_verified=bool(doc.get("is_verified", False)),
        importance=doc.get("importance", "normal"),
        tags=doc.get("tags") or [],
        fields=fields,
        created_at=str(doc.get("created_at", "")),
    )


# ─────────────────────────────── POST /share/create ──────────────────────────

@router.post("/create", response_model=ShareLinkResponse, status_code=status.HTTP_201_CREATED)
async def create_share_link(
    body: ShareLinkCreate,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_sync()
    user_id: str = current_user["id"]
    now = datetime.now(tz=timezone.utc)

    # Verify ownership
    doc_result = supabase.table("documents").select("user_id", "filename").eq("id", body.document_id).execute()
    if not doc_result.data:
        raise HTTPException(status_code=404, detail="Document not found.")
    if doc_result.data[0]["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Access denied.")

    token = uuid4().hex  # 32-char hex, no hyphens
    expires_at = (now + timedelta(hours=body.expires_hours)).isoformat()
    password_hash: Optional[str] = None
    if body.password:
        password_hash = bcrypt.hashpw(
            body.password.encode("utf-8"), bcrypt.gensalt()
        ).decode("utf-8")

    link_row = {
        "token": token,
        "document_id": body.document_id,
        "created_by": user_id,
        "expires_at": expires_at,
        "password_hash": password_hash,
        "is_active": True,
        "created_at": now.isoformat(),
    }
    result = supabase.table("shared_links").insert(link_row).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create share link.")

    return _link_to_response(result.data[0])


# ─────────────────────────────── GET /share/{token} (public) ─────────────────

@router.get("/{token}", response_model=SharedDocumentResponse)
async def get_shared_document(token: str):
    supabase = get_supabase_sync()
    now = datetime.now(tz=timezone.utc).isoformat()

    link_result = supabase.table("shared_links").select("*").eq("token", token).execute()
    if not link_result.data:
        raise HTTPException(status_code=404, detail="Share link not found.")
    link = link_result.data[0]

    if not link.get("is_active"):
        raise HTTPException(status_code=410, detail="This share link has been revoked.")
    if str(link.get("expires_at", "")) < now:
        raise HTTPException(status_code=410, detail="This link has expired.")

    # Fetch document + fields (service role bypasses RLS)
    doc_result = supabase.table("documents").select("*").eq("id", link["document_id"]).execute()
    if not doc_result.data:
        raise HTTPException(status_code=404, detail="Document not found.")
    doc = doc_result.data[0]

    fields_result = supabase.table("document_fields").select("*").eq("document_id", doc["id"]).execute()
    fields = [
        FieldItem(
            id=f.get("id"),
            label=f.get("label", ""),
            value=str(f.get("value", "")),
            confidence=float(f.get("confidence", 1.0)),
            is_copyable=bool(f.get("is_copyable", True)),
        )
        for f in (fields_result.data or [])
    ]

    # Fetch sharer's name
    user_result = supabase.table("users").select("name", "email").eq("id", link["created_by"]).execute()
    sharer = user_result.data[0] if user_result.data else {}
    shared_by = sharer.get("name") or sharer.get("email", "Unknown")

    return SharedDocumentResponse(
        document=_doc_to_response(doc, fields),
        shared_by=shared_by,
        expires_at=str(link.get("expires_at", "")),
        is_password_protected=bool(link.get("password_hash")),
    )


# ─────────────────────────────── POST /share/{token}/verify-password ─────────

@router.post("/{token}/verify-password")
async def verify_share_password(token: str, body: dict):
    supabase = get_supabase_sync()
    link_result = supabase.table("shared_links").select("password_hash").eq("token", token).execute()
    if not link_result.data:
        raise HTTPException(status_code=404, detail="Share link not found.")
    stored_hash = link_result.data[0].get("password_hash")
    if not stored_hash:
        return {"valid": True}  # no password required

    password = body.get("password", "")
    try:
        valid = bcrypt.checkpw(password.encode("utf-8"), stored_hash.encode("utf-8"))
    except Exception:
        valid = False

    return {"valid": valid}


# ─────────────────────────────── DELETE /share/{link_id} ─────────────────────

@router.delete("/{link_id}", status_code=status.HTTP_200_OK)
async def revoke_share_link(
    link_id: str,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_sync()
    link_result = supabase.table("shared_links").select("created_by").eq("id", link_id).execute()
    if not link_result.data:
        raise HTTPException(status_code=404, detail="Share link not found.")
    if link_result.data[0]["created_by"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied.")

    supabase.table("shared_links").update({"is_active": False}).eq("id", link_id).execute()
    return {"message": "Share link revoked."}


# ─────────────────────────────── GET /share ───────────────────────────────────

@router.get("", response_model=list[ShareLinkResponse])
async def list_share_links(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = (
        supabase.table("shared_links")
        .select("*")
        .eq("created_by", current_user["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return [_link_to_response(link) for link in (result.data or [])]
