from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── Gemini ────────────────────────────────────────────────────────────────
    GEMINI_API_KEY: str
    GEMINI_MODEL: str = "gemini-1.5-flash"

    # ── OpenAI (fallback) ─────────────────────────────────────────────────────
    OPENAI_API_KEY: str = ""

    # ── Supabase ──────────────────────────────────────────────────────────────
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    SUPABASE_ANON_KEY: str

    # ── JWT ───────────────────────────────────────────────────────────────────
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 7

    # ── App ───────────────────────────────────────────────────────────────────
    APP_ENV: str = "development"
    MAX_IMAGE_SIZE_MB: int = 10
    SHARE_LINK_EXPIRE_HOURS: int = 48

    @property
    def gemini_api_key(self): return self.GEMINI_API_KEY
    @property
    def gemini_model(self): return self.GEMINI_MODEL
    @property
    def openai_api_key(self): return self.OPENAI_API_KEY
    @property
    def supabase_url(self): return self.SUPABASE_URL
    @property
    def supabase_service_key(self): return self.SUPABASE_SERVICE_KEY
    @property
    def supabase_anon_key(self): return self.SUPABASE_ANON_KEY
    @property
    def jwt_secret(self): return self.JWT_SECRET
    @property
    def jwt_algorithm(self): return self.JWT_ALGORITHM
    @property
    def access_token_expire_minutes(self): return self.JWT_EXPIRE_MINUTES
    @property
    def share_link_expire_hours(self): return self.SHARE_LINK_EXPIRE_HOURS
    @property
    def max_upload_bytes(self): return self.MAX_IMAGE_SIZE_MB * 1024 * 1024
    @property
    def allowed_extensions(self): return "jpg,jpeg,png,pdf,heic"
    @property
    def allowed_extensions_list(self): return ["jpg", "jpeg", "png", "pdf", "heic"]

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()