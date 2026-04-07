from fastapi import APIRouter, HTTPException
from supabase import create_client
from core.config import settings
from core.security import create_access_token
from schemas.responses import ScanResponse

router = APIRouter()

supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)


@router.post("/google")
async def google_login(token: str):
    """
    POST /auth/google
    Exchange a Google OAuth token (from Flutter google_sign_in) for a Supabase session
    and return a JWT for subsequent API calls.
    """
    try:
        response = supabase.auth.sign_in_with_id_token({
            "provider": "google",
            "token": token,
        })
        user = response.user
        if not user:
            raise HTTPException(status_code=401, detail="Google auth failed")

        jwt = create_access_token(user_id=user.id)
        return {
            "jwt": jwt,
            "user_id": user.id,
            "email": user.email,
            "name": user.user_metadata.get("full_name"),
        }
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
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))
