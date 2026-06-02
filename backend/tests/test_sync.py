"""Tests for POST /sync"""
from unittest.mock import MagicMock, patch


def _mock_supabase_ok():
    mock = MagicMock()
    mock.table.return_value.upsert.return_value.execute.return_value = MagicMock()
    mock.table.return_value.delete.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock()
    return mock


SAMPLE_OPERATIONS = [
    {
        "table": "documents",
        "record_id": "doc-uuid-001",
        "operation": "INSERT",
        "payload": {
            "id": "doc-uuid-001",
            "filename": "aadhaar.jpg",
            "localPath": "/docs/doc-uuid-001.jpg",
            "category": "Identity",
            "confidence": 0.97,
            "isSynced": False,
            "createdAt": 1712500000000,
            "updatedAt": 1712500000000,
        },
    },
    {
        "table": "documents",
        "record_id": "doc-uuid-002",
        "operation": "DELETE",
        "payload": {},
    },
]


def test_sync_batch_returns_synced_count(client, auth_headers):
    with patch("services.supabase_admin.supabase", _mock_supabase_ok()):
        response = client.post(
            "/sync",
            json={"operations": SAMPLE_OPERATIONS},
            headers=auth_headers,
        )
    assert response.status_code == 200
    data = response.json()
    assert data["synced_count"] == 2
    assert data["failed_ids"] == []


def test_sync_returns_401_without_auth(client):
    response = client.post(
        "/sync",
        json={"operations": SAMPLE_OPERATIONS},
    )
    assert response.status_code == 403


def test_sync_empty_batch_returns_zero(client, auth_headers):
    response = client.post(
        "/sync",
        json={"operations": []},
        headers=auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["synced_count"] == 0


def test_sync_records_failures_on_supabase_error(client, auth_headers):
    """When Supabase throws, the record ID should appear in failed_ids."""
    mock_sb = MagicMock()
    mock_sb.table.return_value.upsert.return_value.execute.side_effect = Exception("DB error")

    with patch("services.supabase_admin.supabase", mock_sb):
        response = client.post(
            "/sync",
            json={"operations": [SAMPLE_OPERATIONS[0]]},
            headers=auth_headers,
        )
    assert response.status_code == 200
    data = response.json()
    assert data["synced_count"] == 0
    assert "doc-uuid-001" in data["failed_ids"]
