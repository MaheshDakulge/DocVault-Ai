"""Tests for POST /assistant/chat and POST /assistant/eligibility"""
from unittest.mock import patch
from tests.conftest import make_gemini_chat_response, make_gemini_eligibility_response

CONTEXT_FIELDS = [
    {"label": "Name", "value": "Mahesh Dakulge"},
    {"label": "Aadhaar Number", "value": "1234 5678 9012"},
]


def test_chat_returns_answer(client, auth_headers):
    with patch("asyncio.to_thread", return_value=make_gemini_chat_response()):
        response = client.post(
            "/assistant/chat",
            json={"question": "What is my Aadhaar number?", "context_fields": CONTEXT_FIELDS},
            headers=auth_headers,
        )
    assert response.status_code == 200
    data = response.json()
    assert "answer" in data
    assert data["mode"] == "chat"
    assert len(data["answer"]) > 0


def test_chat_returns_401_without_auth(client):
    response = client.post(
        "/assistant/chat",
        json={"question": "test", "context_fields": []},
    )
    assert response.status_code == 403


def test_chat_requires_question_field(client, auth_headers):
    response = client.post(
        "/assistant/chat",
        json={"context_fields": CONTEXT_FIELDS},  # missing 'question'
        headers=auth_headers,
    )
    assert response.status_code == 422


def test_eligibility_returns_matched_schemes(client, auth_headers):
    with patch("asyncio.to_thread", return_value=make_gemini_eligibility_response()):
        response = client.post(
            "/assistant/eligibility",
            json={"question": "What am I eligible for?", "context_fields": CONTEXT_FIELDS},
            headers=auth_headers,
        )
    assert response.status_code == 200
    data = response.json()
    assert "matched_schemes" in data
    assert "summary" in data
    assert len(data["matched_schemes"]) >= 1
    scheme = data["matched_schemes"][0]
    assert "scheme_name" in scheme
    assert "eligibility_score" in scheme
    assert 0.0 <= scheme["eligibility_score"] <= 1.0


def test_eligibility_returns_401_without_auth(client):
    response = client.post(
        "/assistant/eligibility",
        json={"question": "?", "context_fields": []},
    )
    assert response.status_code == 403
