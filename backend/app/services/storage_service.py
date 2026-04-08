"""
app/services/storage_service.py
=================================
Supabase Storage operations for DigiSafe AI.
All functions are synchronous.
"""

from __future__ import annotations

import logging
from uuid import uuid4

from app.core.config import settings
from app.core.database import get_supabase_sync

logger = logging.getLogger(__name__)


def _bucket():
    """Return a _StorageBucket handle for the configured bucket."""
    supabase = get_supabase_sync()
    return supabase.storage().from_(settings.supabase_storage_bucket)


def upload_file(
    file_bytes: bytes,
    user_id: str,
    filename: str,
    content_type: str,
) -> str:
    """
    Upload *file_bytes* to Supabase Storage.

    Returns the storage_path string (e.g. ``docs/{user_id}/{uuid}/{filename}``).
    """
    unique_id = uuid4().hex
    storage_path = f"docs/{user_id}/{unique_id}/{filename}"
    try:
        _bucket().upload(storage_path, file_bytes, content_type)
        logger.info("Uploaded %s → %s", filename, storage_path)
        return storage_path
    except Exception as exc:
        logger.error("upload_file failed: %s", exc)
        raise


def get_signed_url(storage_path: str, expires_in: int = 3600) -> str:
    """
    Return a time-limited signed URL for *storage_path*.

    *expires_in* is the validity window in seconds (default 1 hour).
    """
    try:
        return _bucket().create_signed_url(storage_path, expires_in)
    except Exception as exc:
        logger.error("get_signed_url failed for %s: %s", storage_path, exc)
        return ""


def get_public_url(storage_path: str) -> str:
    """Return the public (unauthenticated) URL for *storage_path*."""
    try:
        return _bucket().get_public_url(storage_path)
    except Exception as exc:
        logger.error("get_public_url failed: %s", exc)
        return ""


def delete_file(storage_path: str) -> bool:
    """
    Delete a file from Supabase Storage.

    Returns True on success, False on failure.
    """
    try:
        _bucket().remove([storage_path])
        return True
    except Exception as exc:
        logger.error("delete_file failed for %s: %s", storage_path, exc)
        return False


def generate_thumbnail_path(storage_path: str) -> str:
    """
    Derive the thumbnail storage path from an original *storage_path*.

    Replaces ``/docs/`` prefix with ``/thumbs/``.
    """
    return storage_path.replace("/docs/", "/thumbs/", 1)
