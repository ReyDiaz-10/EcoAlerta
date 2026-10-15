"""Configuración central segura de EcoAlerta."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Dict, List

from dotenv import load_dotenv
from google import genai


BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


def _clean(value: str | None) -> str:
    return str(value or "").strip().strip('"').strip("'")


def _bool(name: str, default: bool = False) -> bool:
    return _clean(os.getenv(name, str(default))).lower() in {"1", "true", "yes", "si", "sí", "on"}


def _int(name: str, default: int) -> int:
    try:
        return int(_clean(os.getenv(name, str(default))))
    except ValueError as exc:
        raise RuntimeError(f"{name} debe ser un número entero") from exc


APP_ENV = _clean(os.getenv("APP_ENV", "development")).lower()
APP_VERSION = _clean(os.getenv("APP_VERSION", "2.3.5"))
IS_PRODUCTION = APP_ENV == "production"
FORCE_HTTPS = _bool("FORCE_HTTPS", IS_PRODUCTION)
TRUSTED_HOSTS: List[str] = [
    host.strip()
    for host in _clean(os.getenv("TRUSTED_HOSTS", "localhost,127.0.0.1")).split(",")
    if host.strip()
]

SUPABASE_URL = _clean(os.getenv("SUPABASE_URL"))
SUPABASE_SERVICE_KEY = _clean(os.getenv("SUPABASE_SERVICE_KEY"))
SUPABASE_BACKUP_CONTAINER_URL = _clean(os.getenv("SUPABASE_BACKUP_CONTAINER_URL"))
BACKUP_INTERVAL_HOURS = _int("BACKUP_INTERVAL_HOURS", 24)

GENAI_API_KEY = _clean(os.getenv("GENAI_API_KEY"))
GENAI_MODEL_NAMES = [
    name.strip()
    for name in _clean(os.getenv("GENAI_MODEL_NAMES", "gemini-2.5-flash")).split(",")
    if name.strip()
]
CLIENT = genai.Client(api_key=GENAI_API_KEY) if GENAI_API_KEY else None

JWT_SECRET = _clean(os.getenv("JWT_SECRET"))
JWT_ALGORITHM = "HS256"
JWT_EXP_MINUTES = _int("JWT_EXP_MINUTES", 30)
REFRESH_TOKEN_DAYS = _int("REFRESH_TOKEN_DAYS", 7)
ANALYSIS_TOKEN_MINUTES = _int("ANALYSIS_TOKEN_MINUTES", 15)

ADMIN_USER = _clean(os.getenv("ADMIN_USER"))
ADMIN_PASSWORD = _clean(os.getenv("ADMIN_PASSWORD"))

ALLOWED_ORIGINS: List[str] = [
    origin.strip().rstrip("/")
    for origin in _clean(
        os.getenv(
            "ALLOWED_ORIGINS",
            "http://localhost:3000,http://localhost:5500,http://localhost:8000",
        )
    ).split(",")
    if origin.strip()
]
PUBLIC_BASE_URL = _clean(os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")).rstrip("/")

SMTP_SERVER = _clean(os.getenv("SMTP_SERVER", "smtp.gmail.com"))
SMTP_PORT = _int("SMTP_PORT", 587)
CORREO_EMISOR = _clean(os.getenv("CORREO_EMISOR"))
CORREO_PASSWORD = _clean(os.getenv("CORREO_PASSWORD"))
EMAIL_DELIVERY_ENABLED = _bool("EMAIL_DELIVERY_ENABLED", False)
TEST_RECIPIENT_EMAIL = _clean(os.getenv("TEST_RECIPIENT_EMAIL"))

REPORTS_DIR = Path(_clean(os.getenv("REPORTS_DIR")) or str(BASE_DIR / "data" / "informes_pdf")).resolve()
MAX_IMAGES = _int("MAX_IMAGES", 5)
MAX_IMAGE_BYTES = _int("MAX_IMAGE_BYTES", 5 * 1024 * 1024)
MAX_TOTAL_UPLOAD_BYTES = _int("MAX_TOTAL_UPLOAD_BYTES", 15 * 1024 * 1024)
MAX_IMAGE_PIXELS = _int("MAX_IMAGE_PIXELS", 24_000_000)
ALLOW_TEST_MODE = _bool("ALLOW_TEST_MODE", not IS_PRODUCTION)

DICCIONARIO_ENTIDADES: Dict[str, str] = {
    "AMVA_EMERGENCIA": "Área Metropolitana del Valle de Aburrá - Unidad de Emergencias",
    "EPM_ARBOLES_PREVENTIVO": "Empresas Públicas de Medellín (EPM) - Intervenciones Arbóreas",
    "REPORTESMED": "Alcaldía de Medellín - Secretaría de Medio Ambiente (ReportesMed)",
    "EPM_ACUEDUCTO": "Empresas Públicas de Medellín (EPM) - Gestión de Acueducto y Alcantarillado",
    "EPM_ENERGIA": "Empresas Públicas de Medellín (EPM) - Infraestructura de Energía",
    "EPM_ASEO": "Empresas Públicas de Medellín (EPM) - Gestión de Residuos y Aseo",
    "BOMBEROS": "Cuerpo Oficial de Bomberos de Medellín / DAGRD",
    "POLICIA": "Policía Nacional - Protección Ambiental",
    "SECRETARIA_MOVILIDAD": "Secretaría de Movilidad de Medellín",
    "SECRETARIA_INFRAESTRUCTURA": "Secretaría de Infraestructura Física de Medellín",
    "NINGUNA": "Revisión manual EcoAlerta",
}


def _entity_emails() -> Dict[str, str]:
    raw = _clean(os.getenv("ENTITY_EMAILS_JSON"))
    if not raw:
        return {key: "" for key in DICCIONARIO_ENTIDADES}
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError("ENTITY_EMAILS_JSON no contiene JSON válido") from exc
    if not isinstance(parsed, dict):
        raise RuntimeError("ENTITY_EMAILS_JSON debe ser un objeto JSON")
    return {key: _clean(parsed.get(key)) for key in DICCIONARIO_ENTIDADES}


DICCIONARIO_CORREOS_ENTIDADES = _entity_emails()
CARPETA_INFORMES = str(REPORTS_DIR)


def validate_runtime_config() -> None:
    errors: List[str] = []
    if APP_ENV not in {"development", "test", "production"}:
        errors.append("APP_ENV debe ser development, test o production")
    if APP_ENV != "test":
        if not SUPABASE_URL.startswith("https://"):
            errors.append("SUPABASE_URL debe ser una URL HTTPS")
        if not SUPABASE_SERVICE_KEY:
            errors.append("SUPABASE_SERVICE_KEY es obligatoria")
        if len(JWT_SECRET) < 32:
            errors.append("JWT_SECRET debe tener al menos 32 caracteres")
        if SUPABASE_BACKUP_CONTAINER_URL and not SUPABASE_BACKUP_CONTAINER_URL.startswith("https://"):
            errors.append("SUPABASE_BACKUP_CONTAINER_URL debe usar HTTPS")
        if BACKUP_INTERVAL_HOURS < 1:
            errors.append("BACKUP_INTERVAL_HOURS debe ser al menos 1")
    if IS_PRODUCTION:
        if not ALLOWED_ORIGINS or "*" in ALLOWED_ORIGINS:
            errors.append("ALLOWED_ORIGINS no puede estar vacío ni contener * en producción")
        if any("REEMPLAZAR" in origin.upper() for origin in ALLOWED_ORIGINS):
            errors.append("ALLOWED_ORIGINS todavía contiene valores REEMPLAZAR")
        if not PUBLIC_BASE_URL.startswith("https://"):
            errors.append("PUBLIC_BASE_URL debe usar HTTPS en producción")
        if "REEMPLAZAR" in PUBLIC_BASE_URL.upper():
            errors.append("PUBLIC_BASE_URL todavía contiene un valor REEMPLAZAR")
        if not TRUSTED_HOSTS or "*" in TRUSTED_HOSTS:
            errors.append("TRUSTED_HOSTS no puede estar vacío ni contener * en producción")
        if TRUSTED_HOSTS and all(host in {"localhost", "127.0.0.1", "::1"} for host in TRUSTED_HOSTS):
            errors.append("TRUSTED_HOSTS debe incluir el dominio público en producción")
        if any("REEMPLAZAR" in host.upper() for host in TRUSTED_HOSTS):
            errors.append("TRUSTED_HOSTS todavía contiene valores REEMPLAZAR")
        if not FORCE_HTTPS:
            errors.append("FORCE_HTTPS debe ser true en producción")
        if ADMIN_PASSWORD:
            password_checks = (
                len(ADMIN_PASSWORD) >= 12,
                len(ADMIN_PASSWORD.encode("utf-8")) <= 72,
                any(char.islower() for char in ADMIN_PASSWORD),
                any(char.isupper() for char in ADMIN_PASSWORD),
                any(char.isdigit() for char in ADMIN_PASSWORD),
                any(not char.isalnum() for char in ADMIN_PASSWORD),
            )
            if not all(password_checks):
                errors.append(
                    "ADMIN_PASSWORD debe tener entre 12 y 72 bytes e incluir "
                    "mayúscula, minúscula, número y símbolo"
                )
        if EMAIL_DELIVERY_ENABLED and not (CORREO_EMISOR and CORREO_PASSWORD):
            errors.append("Faltan credenciales SMTP para habilitar correo")
        if EMAIL_DELIVERY_ENABLED and not any(DICCIONARIO_CORREOS_ENTIDADES.values()):
            errors.append("Configure al menos un correo de entidad antes de habilitar envíos")
        invalid_entity_emails = [
            key for key, email in DICCIONARIO_CORREOS_ENTIDADES.items()
            if email and ("@" not in email or "." not in email.rsplit("@", 1)[-1])
        ]
        if invalid_entity_emails:
            errors.append("Hay correos de entidad con formato inválido: " + ", ".join(invalid_entity_emails))
        if ALLOW_TEST_MODE:
            errors.append("ALLOW_TEST_MODE debe ser false en producción")
    if errors:
        raise RuntimeError("Configuración insegura:\n- " + "\n- ".join(errors))


def public_settings() -> dict:
    return {
        "environment": APP_ENV,
        "version": APP_VERSION,
        "ai_enabled": CLIENT is not None,
        "email_enabled": EMAIL_DELIVERY_ENABLED,
        "backup_enabled": bool(SUPABASE_BACKUP_CONTAINER_URL),
        "max_images": MAX_IMAGES,
    }
