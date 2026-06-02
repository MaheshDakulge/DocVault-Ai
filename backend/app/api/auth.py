"""
app/api/auth.py
================
Authentication router for DigiSafe AI.

Endpoints:
  POST /auth/signup
  POST /auth/login
  POST /auth/google   (stub — 501)
  GET  /auth/me
  PUT  /auth/me
  POST /auth/logout
  GET  /auth/test-token  (DEV ONLY)
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import settings
from app.core.database import get_supabase_sync
from app.core.security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.schemas.auth_schema import (
    AuthResponse,
    GoogleAuthRequest,
    LoginRequest,
    SignupRequest,
    UpdateProfileRequest,
    UserResponse,
)

router = APIRouter()
logger = logging.getLogger(__name__)


def _to_user_response(user: dict) -> UserResponse:
    """Map a raw Supabase users row → UserResponse schema."""
    return UserResponse(
        id=user["id"],
        email=user["email"],
        name=user.get("name"),
        profile_pic=user.get("profile_pic"),
        role=user.get("role", "user"),
        status=user.get("status", "active"),
        created_at=str(user.get("created_at", "")),
    )


# ─────────────────────────────── POST /signup ─────────────────────────────────

@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def signup(body: SignupRequest):
    supabase = get_supabase_sync()

    existing = (
        supabase.table("users").select("id").eq("email", body.email).execute()
    )
    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )

    try:
        resp = httpx.post(
            f"{settings.supabase_url}/auth/v1/admin/users",
            headers={
                "apikey": settings.supabase_service_key,
                "Authorization": f"Bearer {settings.supabase_service_key}",
                "Content-Type": "application/json",
            },
            json={
                "email": body.email,
                "password": body.password,
                "email_confirm": True,
            },
            timeout=15,
        )
        resp.raise_for_status()
        auth_data = resp.json()
        user_id: str = auth_data["id"]
    except httpx.HTTPStatusError as exc:
        logger.error("Supabase auth signup error: %s", exc.response.text)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not create account. Please try again.",
        )

    password_hash = hash_password(body.password)
    now = datetime.now(tz=timezone.utc).isoformat()
    user_row = {
        "id": user_id,
        "email": body.email,
        "name": body.name,
        "password_hash": password_hash,
        "role": "user",
        "status": "verified",
        "created_at": now,
        "last_seen": now,
    }
    inserted = supabase.table("users").insert(user_row).execute()
    if not inserted.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save user profile.",
        )

    user = inserted.data[0]
    token = create_access_token({"sub": user_id, "email": body.email})
    return AuthResponse(access_token=token, user=_to_user_response(user))


# ─────────────────────────────── POST /login ──────────────────────────────────

@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest):
    supabase = get_supabase_sync()

    result = supabase.table("users").select("*").eq("email", body.email).execute()
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    user = result.data[0]

    if user.get("status") == "banned":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been suspended.",
        )

    if not verify_password(body.password, user.get("password_hash", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    supabase.table("users").update(
        {"last_seen": datetime.now(tz=timezone.utc).isoformat()}
    ).eq("id", user["id"]).execute()

    token = create_access_token({"sub": user["id"], "email": user["email"]})
    return AuthResponse(access_token=token, user=_to_user_response(user))


# ─────────────────────────────── POST /google ─────────────────────────────────

@router.post("/google")
async def google_auth(_body: GoogleAuthRequest):
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Google OAuth will be available in v1.1.",
    )


# ─────────────────────────────── GET /me ──────────────────────────────────────

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    return _to_user_response(current_user)


# ─────────────────────────────── PUT /me ──────────────────────────────────────

@router.put("/me", response_model=UserResponse)
async def update_me(
    body: UpdateProfileRequest,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_sync()
    updates: dict = {}
    if body.name is not None:
        updates["name"] = body.name
    if body.profile_pic is not None:
        updates["profile_pic"] = body.profile_pic

    if not updates:
        return _to_user_response(current_user)

    updates["updated_at"] = datetime.now(tz=timezone.utc).isoformat()
    result = (
        supabase.table("users")
        .update(updates)
        .eq("id", current_user["id"])
        .execute()
    )
    updated = result.data[0] if result.data else {**current_user, **updates}
    return _to_user_response(updated)


# ─────────────────────────────── POST /logout ─────────────────────────────────

@router.post("/logout")
async def logout(_current_user: dict = Depends(get_current_user)):
    return {"message": "Logged out successfully"}


# ─────────────────────────────── DEV ONLY ─────────────────────────────────────

@router.get("/test-token")
async def get_test_token():
    """DEV ONLY — remove this route before going to production."""
    token = create_access_token({"sub": "e5dfd833-3599-4e2e-81f2-abc07533b65d", "email": "maheshm.dakulge@gmail.com"})
    return {"jwt": token}