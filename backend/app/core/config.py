from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    supabase_url: str
    supabase_service_key: str
    supabase_storage_bucket: str = "documents"
    gemini_api_key: str
    gemini_model: str = "gemini-1.5-flash"
    openai_api_key: str = ""
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    app_env: str = "development"
    max_upload_bytes: int = 10 * 1024 * 1024
    allowed_extensions: str = "jpg,jpeg,png,pdf,heic"
    hash_algorithm: str = "sha256"
    share_link_expire_hours: int = 48

    @property
    def allowed_extensions_list(self) -> List[str]:
        return self.allowed_extensions.split(",")

    @property
    def supabase_anon_key(self) -> str:
        return self.supabase_service_key

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()