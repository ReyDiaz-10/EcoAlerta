"""Respaldo lógico periódico de Supabase hacia un contenedor Azure privado."""

from __future__ import annotations

import asyncio
import gzip
import hashlib
import io
import json
import logging
from datetime import datetime, timezone
from typing import Any

import anyio
import requests

from .config import (
    APP_VERSION,
    BACKUP_INTERVAL_HOURS,
    BASE_DIR,
    SUPABASE_BACKUP_CONTAINER_URL,
    SUPABASE_URL,
)
from .db import select_rows


logger = logging.getLogger("ecoalerta.backup")
TABLES = {
    "reportesambientales": "id_reporte.asc",
    "adminusers": "id.asc",
    "feedback": "id.asc",
    "entityresponses": "id.asc",
}
_status: dict[str, str | None] = {
    "last_success_utc": None,
    "last_error_utc": None,
}


def _stable_json(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def _read_table(table: str, order: str) -> list[dict]:
    result: list[dict] = []
    offset = 0
    while True:
        page = select_rows(table, order=order, limit=500, offset=offset)
        result.extend(page)
        if len(page) < 500:
            return result
        offset += 500


def _migration_digest() -> str:
    digest = hashlib.sha256()
    for migration in sorted((BASE_DIR / "migrations").glob("*.sql")):
        digest.update(migration.name.encode("utf-8"))
        digest.update(migration.read_bytes())
    return digest.hexdigest()


def backup_status() -> dict[str, str | None]:
    """Expone solo marcas de tiempo operativas; nunca URLs SAS ni secretos."""
    return dict(_status)


def create_and_upload_backup() -> dict[str, int]:
    if not SUPABASE_BACKUP_CONTAINER_URL:
        return {}
    tables = {name: _read_table(name, order) for name, order in TABLES.items()}
    source_digest = hashlib.sha256(SUPABASE_URL.rstrip("/").lower().encode("utf-8")).hexdigest()
    document = {
        "format": "ecoalerta-supabase-logical-backup",
        "format_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source_url_sha256": source_digest,
        "deployment_version": APP_VERSION,
        "migration_sha256": _migration_digest(),
        "payload_sha256": hashlib.sha256(_stable_json(tables)).hexdigest(),
        "row_counts": {name: len(rows) for name, rows in tables.items()},
        "tables": tables,
    }
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode="wb") as compressed:
        compressed.write(_stable_json(document))

    container, separator, sas = SUPABASE_BACKUP_CONTAINER_URL.partition("?")
    if not separator or not sas:
        raise RuntimeError("SUPABASE_BACKUP_CONTAINER_URL no contiene un SAS válido")
    name = datetime.now(timezone.utc).strftime("supabase/ecoalerta-cloud-%Y%m%d-%H%M%S.json.gz")
    response = requests.put(
        f"{container.rstrip('/')}/{name}?{sas}",
        data=buffer.getvalue(),
        headers={
            "x-ms-blob-type": "BlockBlob",
            "x-ms-version": "2021-12-02",
            "Content-Type": "application/gzip",
        },
        timeout=120,
    )
    if response.status_code not in {200, 201}:
        raise RuntimeError(f"Azure Storage respondió {response.status_code}: {response.text[:200]}")
    _status["last_success_utc"] = datetime.now(timezone.utc).isoformat()
    _status["last_error_utc"] = None
    return document["row_counts"]


async def backup_loop() -> None:
    await asyncio.sleep(60)
    while True:
        try:
            counts = await anyio.to_thread.run_sync(create_and_upload_backup)
            if counts:
                logger.info("Respaldo Supabase cargado correctamente: %s", counts)
        except asyncio.CancelledError:
            raise
        except Exception:
            _status["last_error_utc"] = datetime.now(timezone.utc).isoformat()
            logger.exception("Falló el respaldo periódico de Supabase")
        await asyncio.sleep(max(BACKUP_INTERVAL_HOURS, 1) * 3600)
