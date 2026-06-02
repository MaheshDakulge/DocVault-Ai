"""
app/services/expiry_service.py
================================
Document expiry alert service for DigiSafe AI.
All functions synchronous.
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timezone

from app.core.database import get_supabase_sync

logger = logging.getLogger(__name__)


def format_expiry_message(days_remaining: int, doc_name: str) -> str:
    """Return a human-friendly expiry message."""
    if days_remaining < 0:
        return f"Your {doc_name} expired {abs(days_remaining)} day{'s' if abs(days_remaining) != 1 else ''} ago. Renew immediately."
    if days_remaining == 0:
        return f"Your {doc_name} expires today! Renew immediately."
    if days_remaining <= 7:
        return f"Your {doc_name} expires in {days_remaining} day{'s' if days_remaining != 1 else ''}. Renew now."
    if days_remaining <= 30:
        return f"Your {doc_name} expires in {days_remaining} days."
    return f"Your {doc_name} expires in {days_remaining} days."


def get_expiry_alerts(user_id: str) -> dict:
    """
    Fetch all documents with expiry dates and classify urgency.

    Returns a dict with:
        alerts, critical_count, warning_count, upcoming_count, expired_count
    """
    supabase = get_supabase_sync()

    try:
        result = (
            supabase.table("documents")
            .select("id", "filename", "category", "subcategory", "expiry_date", "importance")
            .eq("user_id", user_id)
            .order("expiry_date", desc=False)
            .execute()
        )
        docs = result.data or []
    except Exception as exc:
        logger.error("get_expiry_alerts fetch error: %s", exc)
        return {
            "alerts": [],
            "critical_count": 0,
            "warning_count": 0,
            "upcoming_count": 0,
            "expired_count": 0,
        }

    today = date.today()
    alerts: list[dict] = []
    critical = warning = upcoming = expired = 0

    for doc in docs:
        expiry_raw = doc.get("expiry_date")
        if not expiry_raw:
            continue

        try:
            expiry_date = date.fromisoformat(str(expiry_raw)[:10])
        except (ValueError, TypeError):
            continue

        days_remaining = (expiry_date - today).days

        if days_remaining > 90:
            continue  # not an alert yet

        if days_remaining < 0:
            urgency = "expired"
            expired += 1
        elif days_remaining <= 7:
            urgency = "critical"
            critical += 1
        elif days_remaining <= 30:
            urgency = "warning"
            warning += 1
        else:
            urgency = "upcoming"
            upcoming += 1

        alerts.append(
            {
                "document_id": doc["id"],
                "filename": doc.get("filename", "Unknown"),
                "category": doc.get("category", "Other"),
                "expiry_date": str(expiry_raw)[:10],
                "days_remaining": days_remaining,
                "urgency": urgency,
                "message": format_expiry_message(days_remaining, doc.get("filename", "document")),
            }
        )

    return {
        "alerts": alerts,
        "critical_count": critical,
        "warning_count": warning,
        "upcoming_count": upcoming,
        "expired_count": expired,
    }
