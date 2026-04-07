from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── Gemini ────────────────────────────────────────────────────────────────
    GEMINI_API_KEY: str

    # ── Supabase ──────────────────────────────────────────────────────────────
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str          # Service role key (backend only)
    SUPABASE_ANON_KEY: str

    # ── JWT ───────────────────────────────────────────────────────────────────
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 7   # 7 days

    # ── App ───────────────────────────────────────────────────────────────────
    APP_ENV: str = "development"          # "development" | "production"
    MAX_IMAGE_SIZE_MB: int = 10
    SHARE_LINK_EXPIRE_HOURS: int = 48

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
