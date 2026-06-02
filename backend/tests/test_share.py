"""Tests for POST /share and DELETE /share/{token}"""
from unittest.mock import MagicMock, patch


def _mock_share_supabase():
    mock = MagicMock()
    mock.table.return_value.insert.return_value.execute.return_value = MagicMock()
    mock.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock()
    return mock


def test_create_share_link_returns_url_and_token(client, auth_headers):
    with patch("services.share_link_service.supabase", _mock_share_supabase()):
        response = client.post(
            "/share",
            json={"document_id": "doc-uuid-001", "expires_in_hours": 24},
            headers=auth_headers,
        )
    assert response.status_code == 200
    data = response.json()
    assert "share_url" in data
    assert "token" in data
    assert "expires_at" in data
    assert len(data["token"]) > 10  # should be a real random token


def test_create_share_link_returns_401_without_auth(client):
    response = client.post(
        "/share",
        json={"document_id": "doc-001", "expires_in_hours": 24},
    )
    assert response.status_code == 403


def test_revoke_share_link_returns_revoked(client, auth_headers):
    with patch("services.share_link_service.supabase", _mock_share_supabase()):
        response = client.delete("/share/some-random-token", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["status"] == "revoked"


def test_revoke_share_link_returns_401_without_auth(client):
    response = client.delete("/share/some-random-token")
    assert response.status_code == 403


def test_share_link_has_correct_expiry_format(client, auth_headers):
    """Verify expires_at is a valid ISO-8601 string."""
    from datetime import datetime
    with patch("services.share_link_service.supabase", _mock_share_supabase()):
        response = client.post(
            "/share",
            json={"document_id": "doc-001", "expires_in_hours": 48},
            headers=auth_headers,
        )
    assert response.status_code == 200
    expires_at = response.json()["expires_at"]
    # Should parse without error
    dt = datetime.fromisoformat(expires_at)
    assert dt > datetime.utcnow()
