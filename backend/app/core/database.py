"""
app/core/database.py
====================
Custom synchronous Supabase REST client built with httpx only.
No supabase-py, no C++ dependencies.

Tables used across the app:
    users, documents, document_fields, shared_links,
    activity_log, upload_jobs, govt_schemes, chat_history
"""

from __future__ import annotations

import json
import logging
from typing import Any, Optional
from urllib.parse import quote

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


# ─────────────────────────────── Helper objects ───────────────────────────────

class _Response:
    """Thin wrapper around a Supabase REST response."""

    def __init__(self, data: list[dict]) -> None:
        self.data = data

    def __repr__(self) -> str:  # pragma: no cover
        return f"<_Response rows={len(self.data)}>"


class _TableQuery:
    """Fluent query builder for a single Supabase table."""

    def __init__(self, client: "SupabaseClient", table_name: str) -> None:
        self._client = client
        self._table = table_name
        self._select_cols: str = "*"
        self._filters: list[str] = []
        self._order_col: Optional[str] = None
        self._order_desc: bool = False
        self._limit_val: Optional[int] = None
        self._body: Optional[dict] = None
        self._method: str = "GET"

    # ── Column selection ───────────────────────────────────────────────────
    def select(self, *columns: str) -> "_TableQuery":
        self._select_cols = ",".join(columns) if columns else "*"
        return self

    # ── Filters ───────────────────────────────────────────────────────────
    def eq(self, column: str, value: Any) -> "_TableQuery":
        self._filters.append(f"{column}=eq.{value}")
        return self

    def neq(self, column: str, value: Any) -> "_TableQuery":
        self._filters.append(f"{column}=neq.{value}")
        return self

    def in_(self, column: str, values: list) -> "_TableQuery":
        joined = ",".join(str(v) for v in values)
        self._filters.append(f"{column}=in.({joined})")
        return self

    def lt(self, column: str, value: Any) -> "_TableQuery":
        self._filters.append(f"{column}=lt.{value}")
        return self

    def lte(self, column: str, value: Any) -> "_TableQuery":
        self._filters.append(f"{column}=lte.{value}")
        return self

    def gt(self, column: str, value: Any) -> "_TableQuery":
        self._filters.append(f"{column}=gt.{value}")
        return self

    def is_(self, column: str, value: Any) -> "_TableQuery":
        self._filters.append(f"{column}=is.{value}")
        return self

    def ilike(self, column: str, pattern: str) -> "_TableQuery":
        self._filters.append(f"{column}=ilike.{quote(pattern, safe='')}")
        return self

    # ── Sorting / pagination ───────────────────────────────────────────────
    def order(self, column: str, *, desc: bool = False) -> "_TableQuery":
        self._order_col = column
        self._order_desc = desc
        return self

    def limit(self, n: int) -> "_TableQuery":
        self._limit_val = n
        return self

    # ── Mutations ─────────────────────────────────────────────────────────
    def insert(self, data: dict) -> "_TableQuery":
        self._method = "POST"
        self._body = data
        return self

    def update(self, data: dict) -> "_TableQuery":
        self._method = "PATCH"
        self._body = data
        return self

    def delete(self) -> "_TableQuery":
        self._method = "DELETE"
        return self

    # ── Execute ───────────────────────────────────────────────────────────
    def execute(self) -> _Response:
        url = f"{self._client.base_url}/rest/v1/{self._table}"

        params: dict[str, str] = {}
        if self._method == "GET":
            params["select"] = self._select_cols
        for f in self._filters:
            key, val = f.split("=", 1)
            params[key] = val
        if self._order_col:
            direction = "desc" if self._order_desc else "asc"
            params["order"] = f"{self._order_col}.{direction}"
        if self._limit_val is not None:
            params["limit"] = str(self._limit_val)

        try:
            with httpx.Client(timeout=30) as client:
                response = client.request(
                    method=self._method,
                    url=url,
                    headers=self._client.headers,
                    params=params,
                    json=self._body,
                )
                response.raise_for_status()
                raw = response.json()
                if isinstance(raw, list):
                    return _Response(raw)
                elif isinstance(raw, dict):
                    return _Response([raw])
                return _Response([])
        except httpx.HTTPStatusError as exc:
            logger.error(
                "Supabase table %s %s error: %s – %s",
                self._method,
                self._table,
                exc.response.status_code,
                exc.response.text,
            )
            raise
        except Exception as exc:
            logger.error("Supabase request failed: %s", exc)
            raise


# ─────────────────────────────── Storage ──────────────────────────────────────

class _StorageBucket:
    """Storage helper for a single Supabase Storage bucket."""

    def __init__(self, client: "SupabaseClient", bucket: str) -> None:
        self._client = client
        self._bucket = bucket

    def _storage_url(self, path: str = "") -> str:
        return f"{self._client.base_url}/storage/v1/object/{self._bucket}/{path}"

    def upload(self, path: str, file_bytes: bytes, content_type: str) -> dict:
        url = self._storage_url(path)
        headers = {**self._client.headers, "Content-Type": content_type}
        with httpx.Client(timeout=120) as client:
            response = client.put(url, headers=headers, content=file_bytes)
            response.raise_for_status()
            return response.json() if response.content else {}

    def get_public_url(self, path: str) -> str:
        return f"{self._client.base_url}/storage/v1/object/public/{self._bucket}/{path}"

    def create_signed_url(self, path: str, expires_in_seconds: int = 3600) -> str:
        url = f"{self._client.base_url}/storage/v1/object/sign/{self._bucket}/{path}"
        with httpx.Client(timeout=30) as client:
            response = client.post(
                url,
                headers=self._client.headers,
                json={"expiresIn": expires_in_seconds},
            )
            response.raise_for_status()
            data = response.json()
            signed_path = data.get("signedURL") or data.get("signedUrl", "")
            if signed_path.startswith("/"):
                base = self._client.base_url.rstrip("/")
                return f"{base}{signed_path}"
            return signed_path

    def download(self, path: str) -> bytes:
        url = self._storage_url(path)
        with httpx.Client(timeout=60) as client:
            response = client.get(url, headers=self._client.headers)
            response.raise_for_status()
            return response.content

    def remove(self, paths: list[str]) -> dict:
        url = f"{self._client.base_url}/storage/v1/object/{self._bucket}"
        with httpx.Client(timeout=30) as client:
            response = client.delete(
                url,
                headers=self._client.headers,
                json={"prefixes": paths},
            )
            response.raise_for_status()
            return response.json() if response.content else {}


# ─────────────────────────────── Auth proxy ───────────────────────────────────

class _AuthResult:
    """Wraps the Supabase auth.get_user response into a simple attribute object."""

    def __init__(self, user_data: dict) -> None:
        self.user = _UserObj(user_data)


class _UserObj:
    def __init__(self, data: dict) -> None:
        self.id = data.get("id") or data.get("sub", "")
        self.email = data.get("email", "")
        meta = data.get("user_metadata") or {}
        self.full_name = meta.get("full_name") or meta.get("name", "")
        self.avatar_url = meta.get("avatar_url") or meta.get("picture", "")


class _Auth:
    def __init__(self, client: "SupabaseClient") -> None:
        self._client = client

    def get_user(self, token: str) -> _AuthResult:
        url = f"{self._client.base_url}/auth/v1/user"
        headers = {
            "apikey": self._client.headers["apikey"],
            "Authorization": f"Bearer {token}",
        }
        with httpx.Client(timeout=15) as client:
            response = client.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
            return _AuthResult(data)


# ─────────────────────────────── Main client ──────────────────────────────────

class SupabaseClient:
    """
    Synchronous Supabase REST client using httpx.
    No supabase-py, no C++ extension dependencies.
    """

    def __init__(self, url: str, key: str) -> None:
        self.base_url = url.rstrip("/")
        self.headers: dict[str, str] = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }
        self.auth = _Auth(self)

    def table(self, table_name: str) -> _TableQuery:
        return _TableQuery(self, table_name)

    def storage(self) -> "_StorageProxy":
        return _StorageProxy(self)


class _StorageProxy:
    """Mirrors the supabase-py storage.from_(bucket) pattern."""

    def __init__(self, client: SupabaseClient) -> None:
        self._client = client

    def from_(self, bucket: str) -> _StorageBucket:
        return _StorageBucket(self._client, bucket)


# ─────────────────────────────── Singleton factory ────────────────────────────

_supabase_client: Optional[SupabaseClient] = None


def get_supabase_sync() -> SupabaseClient:
    """Return the shared SupabaseClient singleton (thread-safe for reads)."""
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = SupabaseClient(
            settings.supabase_url,
            settings.supabase_service_key,
        )
    return _supabase_client
