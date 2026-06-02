"""
app/api/assistant.py
=====================
AI assistant router for DigiSafe AI — powered by Gemini.

Endpoints:
  POST /assistant/chat
  GET  /assistant/expiry
  GET  /assistant/eligibility
  POST /assistant/bundle
  GET  /assistant/verify
  GET  /assistant/history
  DELETE /assistant/history
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.core.database import get_supabase_sync
from app.core.security import get_current_user
from app.schemas.assistant_schema import (
    BundleRequest,
    BundleResponse,
    ChatMessageRequest,
    ChatResponse,
    EligibilityResponse,
    ExpiryResponse,
    SchemeResult,
)
from app.schemas.document_schema import DocumentResponse, FieldItem
from app.services import eligibility_service, expiry_service, bundle_service
from app.services import gemini_service

router = APIRouter()
logger = logging.getLogger(__name__)


def _doc_row_to_response(doc: dict) -> DocumentResponse:
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
        fields=[],
        created_at=str(doc.get("created_at", "")),
    )


# ──────────────────────────────── POST /chat ───────────────────────────────────

@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatMessageRequest,
    current_user: dict = Depends(get_current_user),
):
    user_id: str = current_user["id"]
    supabase = get_supabase_sync()
    now = datetime.now(tz=timezone.utc).isoformat()
    msg_lower = body.message.lower()

    # Detect intent
    if any(kw in msg_lower for kw in ("expir", "renew", "expire")):
        intent = "expiry"
    elif any(kw in msg_lower for kw in ("scheme", "eligible", "qualify", "subsidy", "yojana")):
        intent = "eligibility"
    elif any(kw in msg_lower for kw in ("bundle", "loan", "passport", "apply", "pack", "need documents")):
        intent = "bundle"
    elif any(kw in msg_lower for kw in ("mismatch", "verify", "same name", "match", "different name")):
        intent = "verification"
    else:
        intent = "text"

    # Fetch all user fields for grounded chat
    all_fields: list[dict] = []
    try:
        docs_result = supabase.table("documents").select("id", "filename", "category").eq("user_id", user_id).limit(50).execute()
        doc_ids = [d["id"] for d in (docs_result.data or [])]
        doc_meta = {d["id"]: d for d in (docs_result.data or [])}
        if doc_ids:
            fields_result = supabase.table("document_fields").select("document_id", "label", "value").in_("document_id", doc_ids).execute()
            for f in (fields_result.data or []):
                doc = doc_meta.get(f["document_id"], {})
                all_fields.append({
                    "doc_name": doc.get("filename", "Unknown"),
                    "category": doc.get("category", ""),
                    "label": f["label"],
                    "value": f["value"],
                })
    except Exception as exc:
        logger.warning("Chat field fetch error: %s", exc)

    reply = ""
    message_type = intent
    data = None

    if intent == "expiry":
        alerts_data = expiry_service.get_expiry_alerts(user_id)
        alerts = alerts_data.get("alerts", [])
        if alerts:
            reply = f"You have {len(alerts)} document(s) expiring soon:\n" + "\n".join(
                f"• {a['filename']}: {a.get('message', '')}" for a in alerts[:5]
            )
        else:
            reply = "Great news! None of your documents are expiring in the next 90 days."
        data = alerts_data

    elif intent == "eligibility":
        schemes = eligibility_service.check_eligibility(user_id)
        reply = (
            f"Based on your documents, you may be eligible for {len(schemes)} government scheme(s)."
            if schemes else
            "I couldn't find eligible schemes based on your current documents. Upload more documents for better results."
        )
        data = {"schemes": schemes[:5]}

    elif intent == "bundle":
        # Extract purpose from message
        purpose = body.message.strip()
        bdata = bundle_service.create_bundle(user_id, purpose)
        found = len(bdata.get("found_documents", []))
        missing = bdata.get("missing_document_types", [])
        reply = f"For '{purpose}', you have {found} of the required documents."
        if missing:
            reply += f" You're still missing: {', '.join(missing)}."
        data = bdata

    elif intent == "verification":
        # Cross-document name verification
        docs_result = supabase.table("documents").select("id", "filename", "category").eq("user_id", user_id).execute()
        all_docs = docs_result.data or []
        name_map: dict[str, list[dict]] = {}
        for doc in all_docs:
            fields_r = supabase.table("document_fields").select("label", "value").eq("document_id", doc["id"]).execute()
            for f in (fields_r.data or []):
                if "name" in f["label"].lower():
                    name_val = f["value"].strip().lower()
                    name_map.setdefault(name_val, []).append({"doc": doc["filename"], "value": f["value"]})
        unique_names = len(name_map)
        if unique_names <= 1:
            reply = "✅ All your documents have consistent names. No mismatches found."
        else:
            reply = f"⚠️ Found {unique_names} different names across your documents. Please verify."
        data = {"name_groups": [{"name": n, "found_in": docs} for n, docs in name_map.items()]}

    else:
        # Default Gemini chat
        reply = await gemini_service.process_document_for_chat(
            body.message, all_fields, body.conversation_history
        )

    # Save to chat_history
    try:
        supabase.table("chat_history").insert(
            {"user_id": user_id, "role": "user", "message": body.message, "created_at": now}
        ).execute()
        supabase.table("chat_history").insert(
            {"user_id": user_id, "role": "assistant", "message": reply, "created_at": now}
        ).execute()
    except Exception as exc:
        logger.warning("Chat history save error: %s", exc)

    return ChatResponse(reply=reply, message_type=message_type, data=data)


# ──────────────────────────────── GET /expiry ──────────────────────────────────

@router.get("/expiry", response_model=ExpiryResponse)
async def get_expiry(current_user: dict = Depends(get_current_user)):
    data = expiry_service.get_expiry_alerts(current_user["id"])
    return ExpiryResponse(
        alerts=data["alerts"],
        critical_count=data["critical_count"],
        warning_count=data["warning_count"],
        upcoming_count=data["upcoming_count"],
        expired_count=data.get("expired_count", 0),
    )


# ──────────────────────────────── GET /eligibility ────────────────────────────

@router.get("/eligibility", response_model=EligibilityResponse)
async def get_eligibility(current_user: dict = Depends(get_current_user)):
    schemes = eligibility_service.check_eligibility(current_user["id"])
    return EligibilityResponse(
        eligible_schemes=[SchemeResult(**s) for s in schemes],
        total=len(schemes),
        checked_at=datetime.now(tz=timezone.utc).isoformat(),
    )


# ──────────────────────────────── POST /bundle ────────────────────────────────

@router.post("/bundle", response_model=BundleResponse)
async def create_bundle(
    body: BundleRequest,
    current_user: dict = Depends(get_current_user),
):
    bdata = bundle_service.create_bundle(current_user["id"], body.purpose)
    found_docs = [_doc_row_to_response(d) for d in bdata["found_documents"]]
    return BundleResponse(
        purpose=bdata["purpose"],
        found_documents=found_docs,
        missing_document_types=bdata["missing_document_types"],
        bundle_complete=bdata["bundle_complete"],
        download_available=bdata["download_available"],
    )


# ──────────────────────────────── GET /verify ─────────────────────────────────

@router.get("/verify")
async def verify_documents(current_user: dict = Depends(get_current_user)):
    """Cross-document name mismatch detection."""
    supabase = get_supabase_sync()
    user_id = current_user["id"]

    docs_result = supabase.table("documents").select("id", "filename", "category").eq("user_id", user_id).execute()
    all_docs = docs_result.data or []

    name_variations: dict[str, list[dict]] = {}  # normalised name → list of occurrences

    for doc in all_docs:
        fields_r = supabase.table("document_fields").select("label", "value").eq("document_id", doc["id"]).execute()
        for f in (fields_r.data or []):
            if "name" in f.get("label", "").lower() and f.get("value"):
                norm = f["value"].strip().lower()
                name_variations.setdefault(norm, []).append(
                    {"doc": doc["filename"], "value": f["value"], "category": doc.get("category")}
                )

    # Mismatches = more than 1 unique name key
    if len(name_variations) <= 1:
        return {"mismatches": [], "status": "ok", "message": "All names match across documents."}

    mismatches = [
        {"field": "Name", "values": occurrences}
        for _name, occurrences in name_variations.items()
    ]
    return {"mismatches": mismatches, "status": "mismatch", "total": len(name_variations)}


# ──────────────────────────────── GET /history ────────────────────────────────

@router.get("/history")
async def get_history(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    result = (
        supabase.table("chat_history")
        .select("role", "message", "created_at")
        .eq("user_id", current_user["id"])
        .order("created_at", desc=True)
        .limit(20)
        .execute()
    )
    return list(reversed(result.data or []))


# ──────────────────────────────── DELETE /history ─────────────────────────────

@router.delete("/history")
async def clear_history(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase_sync()
    supabase.table("chat_history").delete().eq("user_id", current_user["id"]).execute()
    return {"message": "Chat history cleared."}
