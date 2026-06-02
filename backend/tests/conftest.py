"""
Shared pytest fixtures for DocsVault AI backend tests.
All external dependencies (Gemini, Supabase) are mocked — no real API keys needed.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

# ── Patch env vars BEFORE importing the app ──────────────────────────────────
import os
os.environ.setdefault("GEMINI_API_KEY", "test-gemini-key")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-anon-key")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-that-is-long-enough-32c")


@pytest.fixture(scope="session")
def app():
    """Create FastAPI app with Gemini + Supabase fully mocked."""
    with patch("google.generativeai.configure"), \
         patch("google.generativeai.GenerativeModel"), \
         patch("supabase.create_client"):
        from main import app as fastapi_app
        return fastapi_app


@pytest.fixture(scope="session")
def client(app):
    return TestClient(app)


@pytest.fixture
def valid_jwt(app):
    """Generate a real JWT signed with the test secret."""
    from core.security import create_access_token
    return create_access_token(user_id="test-user-123")


@pytest.fixture
def auth_headers(valid_jwt):
    return {"Authorization": f"Bearer {valid_jwt}"}


# ── Mock Gemini response helpers ──────────────────────────────────────────────

def make_gemini_scan_response():
    """Fake a successful Gemini scan extraction."""
    import json
    mock_resp = MagicMock()
    mock_resp.text = json.dumps({
        "category": "Identity",
        "subcategory": "Aadhaar Card",
        "fields": [
            {"label": "Name", "value": "Mahesh Dakulge", "confidence": 0.98, "is_copyable": True},
            {"label": "Aadhaar Number", "value": "1234 5678 9012", "confidence": 0.99, "is_copyable": True},
        ],
        "document_date": None,
        "expiry_date": None,
        "confidence": 0.97,
        "raw_text": "Government of India\nMahesh Dakulge\n1234 5678 9012",
    })
    return mock_resp


def make_gemini_chat_response(answer: str = "Your Aadhaar number is 1234 5678 9012."):
    mock_resp = MagicMock()
    mock_resp.text = answer
    return mock_resp


def make_gemini_eligibility_response():
    import json
    mock_resp = MagicMock()
    mock_resp.text = json.dumps([
        {
            "scheme_name": "PM Jan Dhan Yojana",
            "level": "Central",
            "benefit": "Free bank account with ₹10,000 overdraft",
            "apply_url": "https://pmjdy.gov.in",
            "match_reason": "User has Aadhaar card which is required for account opening.",
            "eligibility_score": 0.9,
        }
    ])
    return mock_resp
