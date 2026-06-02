"""
app/schemas/auth_schema.py
==========================
Pydantic v2 schemas for DigiSafe AI authentication endpoints.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ─────────────────────────────── Requests ─────────────────────────────────────

class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    name: str = Field(min_length=2)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str  # Google OAuth id_token from Flutter


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    profile_pic: Optional[str] = None


# ─────────────────────────────── Responses ────────────────────────────────────

class UserResponse(BaseModel):
    id: str
    email: str
    name: Optional[str] = None
    profile_pic: Optional[str] = None
    role: str
    status: str
    created_at: str

    model_config = ConfigDict(from_attributes=True)


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
