"""Tests for POST /scan"""
import io
from unittest.mock import patch
from tests.conftest import make_gemini_scan_response


def test_scan_returns_200_with_valid_image(client, auth_headers):
    fake_image = io.BytesIO(b"\xff\xd8\xff" + b"\x00" * 100)  # minimal JPEG header
    with patch("asyncio.to_thread", return_value=make_gemini_scan_response()):
        response = client.post(
            "/scan",
            files={"file": ("aadhaar.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
    assert response.status_code == 200
    data = response.json()
    assert data["category"] == "Identity"
    assert data["subcategory"] == "Aadhaar Card"
    assert len(data["fields"]) == 2
    assert data["confidence"] == 0.97
    assert "file_hash" in data
    assert len(data["file_hash"]) == 64  # SHA-256 hex digest


def test_scan_returns_401_without_token(client):
    fake_image = io.BytesIO(b"\xff\xd8\xff" + b"\x00" * 100)
    response = client.post(
        "/scan",
        files={"file": ("aadhaar.jpg", fake_image, "image/jpeg")},
    )
    assert response.status_code == 403  # HTTPBearer returns 403 when no creds


def test_scan_returns_413_when_file_too_large(client, auth_headers):
    # 11 MB — exceeds default MAX_IMAGE_SIZE_MB=10
    big_image = io.BytesIO(b"\x00" * (11 * 1024 * 1024))
    response = client.post(
        "/scan",
        files={"file": ("huge.jpg", big_image, "image/jpeg")},
        headers=auth_headers,
    )
    assert response.status_code == 413


def test_scan_returns_valid_sha256(client, auth_headers):
    import hashlib
    content = b"\xff\xd8\xff" + b"\xab" * 100
    with patch("asyncio.to_thread", return_value=make_gemini_scan_response()):
        response = client.post(
            "/scan",
            files={"file": ("doc.jpg", io.BytesIO(content), "image/jpeg")},
            headers=auth_headers,
        )
    assert response.status_code == 200
    expected_hash = hashlib.sha256(content).hexdigest()
    assert response.json()["file_hash"] == expected_hash
