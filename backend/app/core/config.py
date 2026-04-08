"""
app/core/config.py
==================
Pydantic-Settings configuration for DigiSafe AI.
All values are read from the .env file automatically.
"""

from functools import cached_property
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── Supabase ──────────────────────────────────────────────────────────────
    supabase_url: str
    supabase_service_key: str
    supabase_storage_bucket: str = "digisafe"

    # ── Gemini AI ─────────────────────────────────────────────────────────────
    gemini_api_key: str
    gemini_model: str = "gemini-2.0-flash"

    # ── JWT ───────────────────────────────────────────────────────────────────
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440

    # ── App ───────────────────────────────────────────────────────────────────
    app_env: str = "development"
    max_upload_bytes: int = 20971520          # 20 MB
    allowed_extensions: str = "jpg,jpeg,png,pdf,heic"

    # ── Security ──────────────────────────────────────────────────────────────
    hash_algorithm: str = "sha256"
    share_link_expire_hours: int = 24

    # ── Computed properties ───────────────────────────────────────────────────
    @cached_property
    def allowed_extensions_list(self) -> list[str]:
        """Return the comma-separated extension string as a normalised list."""
        return [ext.strip().lower() for ext in self.allowed_extensions.split(",")]

    model_config = {
        # Load from the .env file in the project root
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        # Ignore extra keys that might be present in .env
        "extra": "ignore",
    }


# ── Singleton ─────────────────────────────────────────────────────────────────
settings = Settings()
