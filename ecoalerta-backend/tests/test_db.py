import app.db as db


def test_current_supabase_secret_is_not_sent_as_bearer(monkeypatch):
    monkeypatch.setattr(db, "SUPABASE_SERVICE_KEY", "sb_secret_example")
    headers = db._headers()
    assert headers["apikey"] == "sb_secret_example"
    assert "Authorization" not in headers


def test_legacy_service_role_keeps_bearer_header(monkeypatch):
    monkeypatch.setattr(db, "SUPABASE_SERVICE_KEY", "legacy.service.role")
    headers = db._headers()
    assert headers["Authorization"] == "Bearer legacy.service.role"
