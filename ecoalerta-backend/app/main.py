"""Aplicación FastAPI de EcoAlerta."""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

import anyio
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.trustedhost import TrustedHostMiddleware

from .config import (
    ADMIN_PASSWORD,
    ADMIN_USER,
    ALLOWED_ORIGINS,
    APP_ENV,
    APP_VERSION,
    FORCE_HTTPS,
    REPORTS_DIR,
    TRUSTED_HOSTS,
    public_settings,
    validate_runtime_config,
)
from .db import DatabaseError, healthcheck
from .operational_backup import backup_loop, backup_status
from .rate_limit import rate_limiter
from .routes import router
from .users import create_admin_user, get_admin_user

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("ecoalerta")
WEB_DIR = Path(__file__).resolve().parent.parent / "web"


@asynccontextmanager
async def lifespan(_: FastAPI):
    validate_runtime_config()
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    if APP_ENV != "test":
        await anyio.to_thread.run_sync(healthcheck)
        if ADMIN_USER and ADMIN_PASSWORD:
            existing = await anyio.to_thread.run_sync(lambda: get_admin_user(ADMIN_USER))
            if not existing:
                await anyio.to_thread.run_sync(lambda: create_admin_user(ADMIN_USER, ADMIN_PASSWORD))
                logger.info("Administrador inicial creado")
    logger.info("EcoAlerta %s iniciada en entorno %s", APP_VERSION, APP_ENV)
    backup_task = asyncio.create_task(backup_loop(), name="ecoalerta-supabase-backup")
    try:
        yield
    finally:
        backup_task.cancel()
        try:
            await backup_task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title="EcoAlerta API",
    version=APP_VERSION,
    docs_url="/api/docs" if APP_ENV != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    is_https = request.url.scheme == "https"
    if FORCE_HTTPS and not is_https and request.url.path != "/health":
        return RedirectResponse(url=str(request.url.replace(scheme="https")), status_code=307)

    response = await rate_limiter.middleware(request, call_next)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(self), geolocation=(self)"
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["X-Permitted-Cross-Domain-Policies"] = "none"
    csp = [
        "default-src 'self'",
        "base-uri 'self'",
        "object-src 'none'",
        "frame-ancestors 'none'",
        "form-action 'self'",
        "script-src 'self'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob: https://*.tile.openstreetmap.org",
        "connect-src 'self' https://nominatim.openstreetmap.org",
        "font-src 'self'",
    ]
    if APP_ENV == "production":
        csp.append("upgrade-insecure-requests")
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "; ".join(csp)
    if request.url.path.startswith("/api/admin/") or request.url.path.startswith("/portal/admin"):
        response.headers["Cache-Control"] = "no-store, max-age=0"
        response.headers["Pragma"] = "no-cache"
    return response


app.add_middleware(TrustedHostMiddleware, allowed_hosts=TRUSTED_HOSTS)


@app.exception_handler(DatabaseError)
async def database_error_handler(_: Request, __: DatabaseError):
    return JSONResponse(status_code=503, content={"detail": "Servicio temporalmente no disponible"})


@app.get("/health", tags=["infraestructura"])
async def health():
    try:
        database_ok = True if APP_ENV == "test" else await anyio.to_thread.run_sync(healthcheck)
    except DatabaseError:
        database_ok = False
    return JSONResponse(
        status_code=200 if database_ok else 503,
        content={
            "status": "ok" if database_ok else "degraded",
            "database": database_ok,
            **public_settings(),
            "backup": backup_status(),
        },
    )


app.include_router(router, prefix="/api")

if WEB_DIR.is_dir():
    app.mount("/portal", StaticFiles(directory=WEB_DIR, html=True), name="portal")


@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/portal/")
