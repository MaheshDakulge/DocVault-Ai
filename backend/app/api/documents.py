"""
app/api/documents.py
=====================
Documents CRUD and listing router for DigiSafe AI.

Endpoints:
  GET    /documents
  GET    /documents/tree
  GET    /documents/timeline
  GET    /documents/stats
  GET    /documents/{doc_id}
  PUT    /documents/{doc_id}
  DELETE /documents/{doc_id}
  GET    /documents/{doc_id}/signed-url
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.database import get_supabase_sync
from app.core.security import get_current_user
from app.schemas.document_schema import (
    DocumentResponse,
    DocumentUpdateRequest,
    FieldItem,
    TimelineYearResponse,
    TreeCategoryResponse,
)
from app.services import storage_service

router = APIRouter()
logger = logging.getLogger(__name__)

# ── Category meta ──────────────────────────────────────────────────────────────
_CATEGORY_META: dict[str, dict] = {
    "Identity":   {"icon": "fingerprint",     "color": "#1A3C5E"},
    "Education":  {"icon": "school",           "color": "#166534"},
    "Financial":  {"icon": "account_balance",  "color": "#92400E"},
    "Medical":    {"icon": "medical_services", "color": "#991B1B"},
    "Property":   {"icon": "home",             "color": "#5B21B6"},
    "Legal":      {"icon": "gavel",            "color": "#0F766E"},
    "Other":      {"icon": "folder",           "color": "#64748B"},
}


def _fetch_fields(supabase, doc_id: str) -> list[FieldItem]:
    try:
        result = (
            supabase.table("document_fields")
            .select("id", "label", "value", "confidence", "is_copyable")
            .eq("document_id", doc_id)
            .execute()
        )
        return [FieldItem(**f) for f in (result.data or [])]
    except Exception:
        return []


def _doc_to_response(doc: dict, fields: list[FieldItem] | None = None) -> DocumentResponse:
    tags = doc.get("tags") or []
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
        tags=tags if isinstance(tags, list) else [],
        fields=fields or [],
        created_at=str(doc.get("created_at", "")),
    )


# ─────────────────────────────── GET /documents ───────────────────────────────

@router.get("", response_model=list[DocumentResponse])
async def list_documents(
    category: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_sync()
    query = (
        supabase.table("documents")
        .select("*")
        .eq("user_id", current_user["id"])
        .order("created_at", desc=True)
        .limit(limit)
    )
    if category:
        query = query.eq("category", category)

    result = query.execute()
    docs = result.data or []

    out: list[DocumentResponse] = []
    for doc in docs:
        fields = _fetch_fields(supabase, doc["id"])
        out.append(_doc_to_response(doc, fields))
    return out


# ─────────────────────────────── GET /documents/tree ─────────────────────────

@router.get("/tree", response_model=list[TreeCategoryResponse])
async def documents_tree(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = (
        supabase.table("documents")
        .select("*")
        .eq("user_id", current_user["id"])
        .order("created_at", desc=True)
        .execute()
    )
    docs = result.data or []

    # Group by category
    grouped: dict[str, list[dict]] = {}
    for doc in docs:
        cat = doc.get("category", "Other")
        grouped.setdefault(cat, []).append(doc)

    tree: list[TreeCategoryResponse] = []
    for cat, cat_docs in grouped.items():
        meta = _CATEGORY_META.get(cat, _CATEGORY_META["Other"])
        tree.append(
            TreeCategoryResponse(
                category=cat,
                icon=meta["icon"],
                color=meta["color"],
                count=len(cat_docs),
                documents=[_doc_to_response(d) for d in cat_docs],
            )
        )
    return tree


# ─────────────────────────────── GET /documents/timeline ─────────────────────

@router.get("/timeline", response_model=list[TimelineYearResponse])
async def documents_timeline(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = (
        supabase.table("documents")
        .select("*")
        .eq("user_id", current_user["id"])
        .order("document_date", desc=True)
        .execute()
    )
    docs = result.data or []

    grouped: dict[int, list[dict]] = {}
    for doc in docs:
        raw_date = doc.get("document_date") or doc.get("created_at", "")
        try:
            year = int(str(raw_date)[:4])
        except (ValueError, TypeError):
            year = datetime.now(tz=timezone.utc).year
        grouped.setdefault(year, []).append(doc)

    return [
        TimelineYearResponse(
            year=year,
            count=len(year_docs),
            documents=[_doc_to_response(d) for d in year_docs],
        )
        for year, year_docs in sorted(grouped.items(), reverse=True)
    ]


# ─────────────────────────────── GET /documents/stats ────────────────────────

@router.get("/stats")
async def documents_stats(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    user_id = current_user["id"]

    # All docs
    all_result = supabase.table("documents").select("id", "category", "expiry_date", "is_tampered", "created_at").eq("user_id", user_id).execute()
    docs = all_result.data or []

    now = datetime.now(tz=timezone.utc)
    this_month = sum(
        1 for d in docs
        if str(d.get("created_at", ""))[:7] == now.strftime("%Y-%m")
    )
    from datetime import date, timedelta
    thirty_days = (date.today() + timedelta(days=30)).isoformat()
    expiring_soon = sum(
        1 for d in docs
        if d.get("expiry_date") and d["expiry_date"] <= thirty_days
    )
    categories = len({d.get("category") for d in docs})
    tampered = sum(1 for d in docs if d.get("is_tampered"))

    return {
        "total_documents": len(docs),
        "this_month": this_month,
        "expiring_soon": expiring_soon,
        "categories_count": categories,
        "tampered_count": tampered,
    }


# ─────────────────────────────── GET /documents/{doc_id} ─────────────────────

@router.get("/{doc_id}", response_model=DocumentResponse)
async def get_document(doc_id: str, current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = supabase.table("documents").select("*").eq("id", doc_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Document not found.")
    doc = result.data[0]
    if doc.get("user_id") != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied.")

    fields = _fetch_fields(supabase, doc_id)

    # Activity log
    try:
        supabase.table("activity_log").insert(
            {"user_id": current_user["id"], "document_id": doc_id, "action": "view",
             "created_at": datetime.now(tz=timezone.utc).isoformat()}
        ).execute()
    except Exception:
        pass

    return _doc_to_response(doc, fields)


# ─────────────────────────────── PUT /documents/{doc_id} ─────────────────────

@router.put("/{doc_id}", response_model=DocumentResponse)
async def update_document(
    doc_id: str,
    body: DocumentUpdateRequest,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_sync()
    result = supabase.table("documents").select("user_id").eq("id", doc_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Document not found.")
    if result.data[0].get("user_id") != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied.")

    updates = body.model_dump(exclude_none=True)
    updates["updated_at"] = datetime.now(tz=timezone.utc).isoformat()
    updated = supabase.table("documents").update(updates).eq("id", doc_id).execute()
    doc = updated.data[0] if updated.data else {}
    fields = _fetch_fields(supabase, doc_id)
    return _doc_to_response(doc, fields)


# ─────────────────────────────── DELETE /documents/{doc_id} ──────────────────

@router.delete("/{doc_id}", status_code=status.HTTP_200_OK)
async def delete_document(doc_id: str, current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = supabase.table("documents").select("*").eq("id", doc_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Document not found.")
    doc = result.data[0]
    if doc.get("user_id") != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied.")

    # Delete file from storage
    if doc.get("storage_path"):
        storage_service.delete_file(doc["storage_path"])

    # Delete fields (cascade should handle this, but be explicit)
    try:
        supabase.table("document_fields").delete().eq("document_id", doc_id).execute()
    except Exception:
        pass

    supabase.table("documents").delete().eq("id", doc_id).execute()

    # Activity log
    try:
        supabase.table("activity_log").insert(
            {"user_id": current_user["id"], "document_id": doc_id, "action": "delete",
             "detail": f"Deleted: {doc.get('filename')}",
             "created_at": datetime.now(tz=timezone.utc).isoformat()}
        ).execute()
    except Exception:
        pass

    return {"message": "Document deleted successfully."}


# ─────────────────────────────── GET /{doc_id}/signed-url ────────────────────

@router.get("/{doc_id}/signed-url")
async def get_signed_url(doc_id: str, current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = supabase.table("documents").select("user_id", "storage_path").eq("id", doc_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Document not found.")
    doc = result.data[0]
    if doc.get("user_id") != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied.")
    if not doc.get("storage_path"):
        raise HTTPException(status_code=404, detail="No file associated with this document.")

    url = storage_service.get_signed_url(doc["storage_path"], expires_in=3600)
    return {"url": url, "expires_in": 3600}
