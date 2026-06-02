"""
app/services/bundle_service.py
================================
Document bundle / application pack service for DigiSafe AI.
Helps users collect exactly the documents needed for a specific purpose.
All functions synchronous.
"""

from __future__ import annotations

import logging
from typing import Optional

from app.core.database import get_supabase_sync

logger = logging.getLogger(__name__)

# ─────────────────────────────── Bundle templates ─────────────────────────────

BUNDLE_TEMPLATES: dict[str, list[str]] = {
    "home loan": ["Aadhaar Card", "PAN Card", "Bank Statement", "Income Certificate", "Property Document"],
    "personal loan": ["Aadhaar Card", "PAN Card", "Bank Statement", "Salary Slip"],
    "passport": ["Birth Certificate", "Aadhaar Card", "PAN Card", "Address Proof"],
    "passport renewal": ["Passport", "Aadhaar Card", "PAN Card"],
    "college admission": ["Marksheet", "Transfer Certificate", "Caste Certificate", "Income Certificate", "Aadhaar Card"],
    "visa": ["Passport", "Bank Statement", "Employment Certificate", "ITR"],
    "job application": ["Degree Certificate", "Marksheet", "Aadhaar Card", "PAN Card"],
    "ration card": ["Aadhaar Card", "Income Certificate", "Address Proof"],
    "driving license": ["Aadhaar Card", "Birth Certificate", "Address Proof"],
    "scholarship": ["Marksheet", "Income Certificate", "Caste Certificate", "Aadhaar Card"],
    "insurance claim": ["Policy Document", "Aadhaar Card", "Medical Report", "Bank Statement"],
    "property registration": ["Aadhaar Card", "PAN Card", "Property Document", "Income Certificate"],
}


def _normalise(s: str) -> str:
    return str(s).lower().strip()


def _find_template(purpose: str) -> Optional[list[str]]:
    """Fuzzy-match *purpose* against BUNDLE_TEMPLATES keys."""
    p = _normalise(purpose)
    # Exact match first
    if p in BUNDLE_TEMPLATES:
        return BUNDLE_TEMPLATES[p]
    # Substring match
    for key, docs in BUNDLE_TEMPLATES.items():
        if key in p or p in key:
            return docs
    # Word-level overlap
    purpose_words = set(p.split())
    best_key = max(
        BUNDLE_TEMPLATES,
        key=lambda k: len(set(k.split()) & purpose_words),
        default=None,
    )
    if best_key:
        overlap = len(set(best_key.split()) & purpose_words)
        if overlap >= 1:
            return BUNDLE_TEMPLATES[best_key]
    return None


def _doc_matches_type(doc: dict, required_type: str) -> bool:
    """Check if a user document matches the required type string."""
    req = _normalise(required_type)
    subcategory = _normalise(doc.get("subcategory") or "")
    category = _normalise(doc.get("category") or "")
    filename = _normalise(doc.get("filename") or "")
    return req in subcategory or req in filename or subcategory in req or req in category


def create_bundle(user_id: str, purpose: str) -> dict:
    """
    Match a user's uploaded documents against what is needed for *purpose*.

    Returns a bundle dict with found_documents, missing_document_types,
    bundle_complete, and download_available flags.
    """
    supabase = get_supabase_sync()

    # Find template
    required_types = _find_template(purpose)

    if not required_types:
        # Fallback: ask Gemini (import lazily to avoid circular deps)
        try:
            import asyncio
            from app.services.gemini_service import _model  # reuse the configured model
            prompt = (
                f"List the documents typically required for '{purpose}' in India. "
                "Return only a JSON array of document type names, e.g. "
                '[\"Aadhaar Card\", \"PAN Card\"]. No explanation.'
            )
            response = _model.generate_content(prompt)
            import json, re
            raw = response.text or "[]"
            match = re.search(r"\[.*\]", raw, re.DOTALL)
            required_types = json.loads(match.group()) if match else []
        except Exception as exc:
            logger.warning("bundle Gemini fallback failed: %s", exc)
            required_types = []

    # Fetch user documents
    try:
        result = (
            supabase.table("documents")
            .select("id", "filename", "category", "subcategory", "doc_type",
                    "document_date", "expiry_date", "owner_name", "storage_path",
                    "is_tampered", "is_verified", "importance", "created_at",
                    "ocr_confidence", "tags")
            .eq("user_id", user_id)
            .execute()
        )
        user_docs = result.data or []
    except Exception as exc:
        logger.error("create_bundle fetch error: %s", exc)
        user_docs = []

    found_documents: list[dict] = []
    missing_document_types: list[str] = []

    for req_type in required_types:
        matches = [d for d in user_docs if _doc_matches_type(d, req_type)]
        if matches:
            # Use the most recent match
            best = sorted(matches, key=lambda d: d.get("created_at", ""), reverse=True)[0]
            # Avoid duplicates
            if not any(f["id"] == best["id"] for f in found_documents):
                found_documents.append(best)
        else:
            missing_document_types.append(req_type)

    return {
        "purpose": purpose,
        "found_documents": found_documents,
        "missing_document_types": missing_document_types,
        "bundle_complete": len(missing_document_types) == 0,
        "download_available": len(found_documents) > 0,
    }
