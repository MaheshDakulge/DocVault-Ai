from pydantic import BaseModel
from fastapi import APIRouter, HTTPException
from supabase import create_client
from core.config import settings
from core.security import create_access_token

router = APIRouter()

supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)


class GoogleTokenRequest(BaseModel):
    """JSON body for Google ID-token exchange."""
    token: str


@router.post("/google")
async def google_login(body: GoogleTokenRequest):
    """
    POST /auth/google
    Exchange a Google ID-token (from Flutter google_sign_in) for a Supabase
    session and return a custom JWT for subsequent API calls.
    """
    try:
        response = supabase.auth.sign_in_with_id_token({
            "provider": "google",
            "token": body.token,
        })
        user = response.user
        if not user:
            raise HTTPException(status_code=401, detail="Google auth failed: no user returned")

        jwt = create_access_token(user_id=user.id)
        return {
            "jwt": jwt,
            "user_id": user.id,
            "email": user.email,
            "name": user.user_metadata.get("full_name"),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/refresh")
async def refresh_token(refresh_token: str):
    """POST /auth/refresh — Exchange a Supabase refresh token for a new JWT."""
    try:
        response = supabase.auth.refresh_session(refresh_token)
        user = response.user
        if not user:
            raise HTTPException(status_code=401, detail="Refresh failed")
        jwt = create_access_token(user_id=user.id)
        return {"jwt": jwt}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


# ── DEV ONLY — remove before production ──────────────────────────────────────
@router.get("/test-token")
async def get_test_token():
    """
    GET /auth/test-token
    Returns a valid JWT for your existing Supabase user.
    FOR TESTING ONLY — delete this route before going to production.
    """
    jwt = create_access_token(user_id="e5dfd833-3599-4e2e-81f2-abc07533b65d")
    return {
        "jwt": jwt,
        "user_id": "e5dfd833-3599-4e2e-81f2-abc07533b65d",
        "note": "DEV ONLY — remove this route in production"
    }