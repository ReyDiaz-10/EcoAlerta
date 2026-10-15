from fastapi import HTTPException
import pytest

import app.auth as auth
from app.auth import (
    create_access_token,
    create_analysis_token,
    verify_admin_token,
    verify_analysis_token,
    verify_token,
)


def test_access_token_round_trip():
    payload = verify_token(create_access_token("admin"))
    assert payload["sub"] == "admin"
    assert payload["type"] == "access"


def test_analysis_token_is_bound_to_images():
    token = create_analysis_token(["abc"], {"valido": True})
    assert verify_analysis_token(token, ["abc"])["valido"] is True
    with pytest.raises(HTTPException) as error:
        verify_analysis_token(token, ["different"])
    assert error.value.status_code == 400


def test_password_change_invalidates_previous_access_token(monkeypatch):
    user = {"password_hash": "$2b$12$hash-before"}
    monkeypatch.setattr(auth, "get_admin_user", lambda _: user)
    marker = auth._admin_token_marker(user["password_hash"])
    token = create_access_token("admin", marker)

    assert verify_admin_token(token)["sub"] == "admin"
    user["password_hash"] = "$2b$12$hash-after"

    with pytest.raises(HTTPException) as error:
        verify_admin_token(token)
    assert error.value.status_code == 401
