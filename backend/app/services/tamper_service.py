"""
app/services/tamper_service.py
================================
Tamper detection and duplicate checking via SHA-256 hash comparison.
All functions are synchronous.
"""

from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timezone
from typing import Optional

from app.core.database import get_supabase_sync

logger = logging.getLogger(__name__)


def compute_hash(file_bytes: bytes) -> str:
    """Return the SHA-256 hex digest of *file_bytes*."""
    return hashlib.sha256(file_bytes).hexdigest()


def verify_integrity(file_bytes: bytes, stored_hash: str) -> bool:
    """
    Re-hash *file_bytes* and compare against *stored_hash*.

    Returns True if the file is unmodified, False if it has been tampered with.
    """
    current_hash = compute_hash(file_bytes)
    return current_hash == stored_hash


def check_duplicate(file_hash: str, user_id: str) -> Optional[dict]:
    """
    Check whether *user_id* already owns a document with the same hash.

    Returns the existing document dict if a duplicate is found, else None.
    """
    try:
        supabase = get_supabase_sync()
        result = (
            supabase.table("documents")
            .select("id", "filename", "category")
            .eq("user_id", user_id)
            .eq("fileHash", file_hash)
            .execute()
        )
        if result.data:
            return result.data[0]
        return None
    except Exception as exc:
        logger.error("check_duplicate error: %s", exc)
        return None


def flag_tampered(document_id: str, reason: str) -> None:
    """
    Mark a document as tampered in the database and log the event.
    Best-effort — failures are logged but not raised.
    """
    supabase = get_supabase_sync()
    now = datetime.now(tz=timezone.utc).isoformat()
    tamper_flag = [{"reason": reason, "detected_at": now}]

    try:
        supabase.table("documents").update(
            {
                "is_tampered": True,
                "tamper_flags": tamper_flag,
                "updated_at": now,
            }
        ).eq("id", document_id).execute()
    except Exception as exc:
        logger.error("flag_tampered update error for %s: %s", document_id, exc)

    # Log to activity_log
    try:
        supabase.table("activity_log").insert(
            {
                "document_id": document_id,
                "action": "tamper_detected",
                "detail": reason,
                "created_at": now,
            }
        ).execute()
    except Exception as exc:
        logger.error("flag_tampered activity_log error: %s", exc)
