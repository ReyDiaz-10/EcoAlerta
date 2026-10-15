"""Tokens JWT y autenticación administrativa."""

from __future__ import annotations

import hashlib
import hmac
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List

import jwt
from fastapi import HTTPException

from .config import (
    ANALYSIS_TOKEN_MINUTES,
    JWT_ALGORITHM,
    JWT_EXP_MINUTES,
    JWT_SECRET,
    REFRESH_TOKEN_DAYS,
)
from .users import (
    clear_refresh_token,
    get_admin_user,
    set_refresh_token,
    validate_refresh_token,
    verify_password,
)


def _admin_token_marker(password_hash: str) -> str:
    return hmac.new(
        JWT_SECRET.encode("utf-8"),
        password_hash.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _encode(subject: str, token_type: str, expires: timedelta, extra: Dict[str, Any] | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload: Dict[str, Any] = {
        "sub": subject,
        "iat": now,
        "nbf": now,
        "exp": now + expires,
        "type": token_type,
        "jti": uuid.uuid4().hex,
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_access_token(subject: str, auth_marker: str = "") -> str:
    extra = {"av": auth_marker} if auth_marker else None
    return _encode(subject, "access", timedelta(minutes=JWT_EXP_MINUTES), extra)


def create_refresh_token(subject: str, auth_marker: str = "") -> str:
    extra = {"av": auth_marker} if auth_marker else None
    return _encode(subject, "refresh", timedelta(days=REFRESH_TOKEN_DAYS), extra)


def _decode(token: str, expected_type: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
            options={"require": ["exp", "iat", "sub", "type"]},
        )
        if payload.get("type") != expected_type:
            raise HTTPException(status_code=401, detail="Token inválido")
        return payload
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=401, detail="Token expirado") from exc
    except HTTPException:
        raise
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Token inválido") from exc


def verify_token(token: str) -> dict:
    return _decode(token, "access")


def verify_admin_token(token: str) -> dict:
    payload = verify_token(token)
    username = str(payload.get("sub") or "")
    user = get_admin_user(username) if username else None
    expected = _admin_token_marker(str((user or {}).get("password_hash") or "")) if user else ""
    supplied = str(payload.get("av") or "")
    if not expected or not supplied or not hmac.compare_digest(expected, supplied):
        raise HTTPException(status_code=401, detail="Sesión inválida")
    return payload


def verify_refresh_token(token: str) -> dict:
    return _decode(token, "refresh")


def authenticate_admin(username: str, password: str) -> bool:
    user = get_admin_user(username)
    return bool(user) and verify_password(password, str(user.get("password_hash") or ""))


def issue_login_tokens(username: str) -> dict:
    user = get_admin_user(username)
    if not user:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    auth_marker = _admin_token_marker(str(user.get("password_hash") or ""))
    access_token = create_access_token(username, auth_marker)
    refresh_token = create_refresh_token(username, auth_marker)
    set_refresh_token(username, refresh_token)
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": JWT_EXP_MINUTES * 60,
    }


def rotate_refresh_token(token: str) -> dict:
    payload = verify_refresh_token(token)
    username = str(payload.get("sub") or "")
    user = get_admin_user(username) if username else None
    supplied_marker = str(payload.get("av") or "")
    expected_marker = _admin_token_marker(str((user or {}).get("password_hash") or "")) if user else ""
    if (
        not username
        or not expected_marker
        or not supplied_marker
        or not hmac.compare_digest(expected_marker, supplied_marker)
        or not validate_refresh_token(username, token)
    ):
        raise HTTPException(status_code=401, detail="Refresh token inválido")
    return issue_login_tokens(username)


def revoke_session(username: str) -> None:
    clear_refresh_token(username)


def create_analysis_token(image_hashes: List[str], analysis: dict) -> str:
    return _encode(
        "image-analysis",
        "analysis",
        timedelta(minutes=ANALYSIS_TOKEN_MINUTES),
        {"image_hashes": image_hashes, "analysis": analysis},
    )


def verify_analysis_token(token: str, image_hashes: List[str]) -> dict:
    payload = _decode(token, "analysis")
    if payload.get("image_hashes") != image_hashes:
        raise HTTPException(status_code=400, detail="Las imágenes cambiaron; se requiere un nuevo análisis")
    analysis = payload.get("analysis")
    if not isinstance(analysis, dict):
        raise HTTPException(status_code=400, detail="Análisis previo inválido")
    return analysis
