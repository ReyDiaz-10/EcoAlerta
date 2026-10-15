"""Gestión segura de administradores."""

from __future__ import annotations

import hashlib
import hmac
from typing import Optional

import bcrypt

from .db import create_admin, get_admin, update_admin


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), str(password_hash).encode("utf-8"))
    except (ValueError, TypeError):
        return False


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def get_admin_user(username: str) -> Optional[dict]:
    return get_admin(username)


def create_admin_user(username: str, password: str) -> bool:
    if get_admin_user(username):
        return False
    create_admin({"username": username, "password_hash": hash_password(password)})
    return True


def change_admin_password(username: str, current_password: str, new_password: str) -> bool:
    user = get_admin_user(username)
    if not user or not verify_password(current_password, str(user.get("password_hash") or "")):
        return False
    update_admin(
        username,
        {
            "password_hash": hash_password(new_password),
            "refresh_token_hash": None,
        },
    )
    return True


def set_refresh_token(username: str, token: str) -> None:
    update_admin(username, {"refresh_token_hash": hash_refresh_token(token)})


def clear_refresh_token(username: str) -> None:
    update_admin(username, {"refresh_token_hash": None})


def validate_refresh_token(username: str, token: str) -> bool:
    user = get_admin_user(username)
    expected = str((user or {}).get("refresh_token_hash") or "")
    return bool(expected) and hmac.compare_digest(expected, hash_refresh_token(token))
