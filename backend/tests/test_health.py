"""Tests for GET /health"""
from tests.conftest import *  # noqa: F401,F403


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "docsvault" in data["service"]
