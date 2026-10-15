import app.users as users


def test_password_change_replaces_hash_and_revokes_refresh(monkeypatch):
    current_hash = users.hash_password("Anterior#123")
    captured = {}
    monkeypatch.setattr(users, "get_admin_user", lambda _: {"password_hash": current_hash})
    monkeypatch.setattr(users, "update_admin", lambda username, payload: captured.update({
        "username": username,
        "payload": payload,
    }))

    assert users.change_admin_password("administrador", "Anterior#123", "NuevaClave#456") is True
    assert captured["username"] == "administrador"
    assert captured["payload"]["refresh_token_hash"] is None
    assert users.verify_password("NuevaClave#456", captured["payload"]["password_hash"])
    assert not users.verify_password("Anterior#123", captured["payload"]["password_hash"])
