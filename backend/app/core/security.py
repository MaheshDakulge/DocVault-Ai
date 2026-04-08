"""
app/core/security.py
====================
JWT utilities and FastAPI dependency helpers for DigiSafe AI.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import settings
from app.core.database import get_supabase_sync

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=True)
_bearer_scheme_optional = HTTPBearer(auto_error=False)


# ─────────────────────────────── Password helpers ─────────────────────────────

def hash_password(password: str) -> str:
    """Hash a plain-text password with bcrypt and return the decoded string."""
    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Return True if *plain* matches the bcrypt *hashed* string."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


# ─────────────────────────────── JWT helpers ──────────────────────────────────

def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Encode *data* as a signed JWT.

    The token expiry defaults to ``settings.access_token_expire_minutes``.
    """
    payload = data.copy()
    if expires_delta:
        expire = datetime.now(tz=timezone.utc) + expires_delta
    else:
        expire = datetime.now(tz=timezone.utc) + timedelta(
            minutes=settings.access_token_expire_minutes
        )
    payload["exp"] = expire
    return jwt.encode(
        payload,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


# ─────────────────────────────── FastAPI dependencies ─────────────────────────

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
) -> dict:
    """
    FastAPI dependency — resolves the Bearer token to a user row.

    1. Verifies the token against Supabase Auth (never decodes locally).
    2. Fetches the matching row from the *users* table.
    3. Updates the ``last_seen`` timestamp.
    """
    token = credentials.credentials
    supabase = get_supabase_sync()

    # 1. Verify token with Supabase Auth
    try:
        auth_result = supabase.auth.get_user(token)
        user_id: str = auth_result.user.id
    except Exception as exc:
        logger.warning("Supabase token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    # 2. Fetch user row — auto-create if missing (e.g. first login via Google)
    try:
        result = (
            supabase.table("users")
            .select("*")
            .eq("id", user_id)
            .execute()
        )
    except Exception as exc:
        logger.error("DB error fetching user: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error",
        )

    if not result.data:
        # First time this user hits the backend — create their profile row
        logger.info("Auto-creating user profile for %s", user_id)
        try:
            auth_user = auth_result.user
            insert_result = supabase.table("users").insert({
                "id": user_id,
                "email": auth_user.email,
                "full_name": auth_user.full_name,
                "avatar_url": auth_user.avatar_url,
            }).execute()
            if not insert_result.data:
                raise RuntimeError("Empty insert result")
            result = insert_result
        except Exception as exc:
            logger.error("Failed to auto-create user profile: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not create user profile",
            )

    user = result.data[0]

    # 3. Update last_seen (best-effort)
    try:
        from datetime import datetime, timezone
        supabase.table("users").update(
            {"last_seen": datetime.now(tz=timezone.utc).isoformat()}
        ).eq("id", user_id).execute()
    except Exception:
        pass  # non-critical

    return user


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        _bearer_scheme_optional
    ),
) -> Optional[dict]:
    """
    Like :func:`get_current_user` but returns *None* instead of raising
    an exception.  Used for public share routes that optionally know the
    caller's identity.
    """
    if credentials is None:
        return None
    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None
