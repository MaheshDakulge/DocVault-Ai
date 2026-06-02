"""Tests for POST /auth/google and POST /auth/refresh"""
from unittest.mock import MagicMock, patch


def _make_supabase_user(user_id="test-user-123", email="test@example.com"):
    user = MagicMock()
    user.id = user_id
    user.email = email
    user.user_metadata = {"full_name": "Mahesh Dakulge"}
    resp = MagicMock()
    resp.user = user
    return resp


def test_google_login_returns_jwt_on_success(client):
    with patch("api.routes.auth.supabase") as mock_sb:
        mock_sb.auth.sign_in_with_id_token.return_value = _make_supabase_user()
        response = client.post("/auth/google", json={"token": "valid-google-id-token"})

    assert response.status_code == 200
    data = response.json()
    assert "jwt" in data
    assert data["email"] == "test@example.com"
    assert data["user_id"] == "test-user-123"


def test_google_login_returns_401_on_bad_token(client):
    with patch("api.routes.auth.supabase") as mock_sb:
        mock_sb.auth.sign_in_with_id_token.side_effect = Exception("invalid_token")
        response = client.post("/auth/google", json={"token": "bad-token"})

    assert response.status_code == 401


def test_google_login_returns_401_when_no_user(client):
    with patch("api.routes.auth.supabase") as mock_sb:
        resp = MagicMock()
        resp.user = None
        mock_sb.auth.sign_in_with_id_token.return_value = resp
        response = client.post("/auth/google", json={"token": "token-with-no-user"})

    assert response.status_code == 401


def test_google_login_requires_json_body(client):
    # Old query-param style must be rejected
    response = client.post("/auth/google?token=some-token")
    assert response.status_code == 422  # Unprocessable — body missing
