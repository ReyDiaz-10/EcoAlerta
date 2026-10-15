"""Respaldo lógico y restauración controlada de los datos de EcoAlerta."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv


TABLES = {
    "reportesambientales": "id_reporte.asc",
    "adminusers": "id.asc",
    "feedback": "id.asc",
    "entityresponses": "id.asc",
}
FORMAT_VERSION = 1


class BackupError(RuntimeError):
    pass


def clean(value: str | None) -> str:
    return str(value or "").strip().strip('"').strip("'")


def source_hash(url: str) -> str:
    normalized = url.rstrip("/").lower().encode("utf-8")
    return hashlib.sha256(normalized).hexdigest()


def headers(service_key: str, prefer: str = "count=exact") -> dict[str, str]:
    result = {
        "apikey": service_key,
        "Content-Type": "application/json",
        "Prefer": prefer,
    }
    if not service_key.startswith("sb_secret_"):
        result["Authorization"] = f"Bearer {service_key}"
    return result


def stable_json(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def fetch_table(base_url: str, service_key: str, table: str, order: str) -> list[dict]:
    rows: list[dict] = []
    page_size = 500
    offset = 0
    while True:
        response = requests.get(
            f"{base_url.rstrip('/')}/rest/v1/{table}",
            headers=headers(service_key),
            params={
                "select": "*",
                "order": order,
                "limit": str(page_size),
                "offset": str(offset),
            },
            timeout=60,
        )
        if response.status_code >= 400:
            raise BackupError(
                f"Supabase respondió {response.status_code} al leer {table}: "
                f"{response.text[:240]}"
            )
        page = response.json()
        if not isinstance(page, list):
            raise BackupError(f"La respuesta de {table} no es una lista JSON")
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += page_size


def migration_digest(root: Path) -> str:
    migrations = sorted((root / "ecoalerta-backend" / "migrations").glob("*.sql"))
    digest = hashlib.sha256()
    for migration in migrations:
        digest.update(migration.name.encode("utf-8"))
        digest.update(migration.read_bytes())
    return digest.hexdigest()


def create_backup(root: Path, output: Path) -> dict[str, Any]:
    load_dotenv(root / "ecoalerta-backend" / ".env")
    base_url = clean(os.getenv("SUPABASE_URL"))
    service_key = clean(os.getenv("SUPABASE_SERVICE_KEY"))
    if not base_url.startswith("https://") or not service_key:
        raise BackupError("Faltan SUPABASE_URL o SUPABASE_SERVICE_KEY en ecoalerta-backend/.env")

    data = {
        table: fetch_table(base_url, service_key, table, order)
        for table, order in TABLES.items()
    }
    payload_digest = hashlib.sha256(stable_json(data)).hexdigest()
    document = {
        "format": "ecoalerta-supabase-logical-backup",
        "format_version": FORMAT_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source_url_sha256": source_hash(base_url),
        "migration_sha256": migration_digest(root),
        "payload_sha256": payload_digest,
        "row_counts": {table: len(rows) for table, rows in data.items()},
        "tables": data,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(output, "wt", encoding="utf-8", newline="\n") as handle:
        json.dump(document, handle, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return {
        "ok": True,
        "archivo": str(output),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "filas": document["row_counts"],
    }


def load_and_validate(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise BackupError(f"No existe el respaldo: {path}")
    try:
        with gzip.open(path, "rt", encoding="utf-8") as handle:
            document = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise BackupError(f"El respaldo no es un JSON GZip válido: {exc}") from exc

    if document.get("format") != "ecoalerta-supabase-logical-backup":
        raise BackupError("Formato de respaldo no reconocido")
    if document.get("format_version") != FORMAT_VERSION:
        raise BackupError("Versión de respaldo no compatible")
    tables = document.get("tables")
    if not isinstance(tables, dict) or set(tables) != set(TABLES):
        raise BackupError("El respaldo no contiene el conjunto exacto de tablas esperado")
    for table, rows in tables.items():
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise BackupError(f"La tabla {table} contiene datos inválidos")
    digest = hashlib.sha256(stable_json(tables)).hexdigest()
    if digest != document.get("payload_sha256"):
        raise BackupError("La suma SHA-256 del contenido no coincide")
    counts = {table: len(rows) for table, rows in tables.items()}
    if counts != document.get("row_counts"):
        raise BackupError("Los conteos declarados no coinciden con el contenido")
    return document


def restore_backup(path: Path, target_url: str, target_key: str) -> dict[str, Any]:
    document = load_and_validate(path)
    if source_hash(target_url) == document["source_url_sha256"]:
        raise BackupError("Se rechazó la restauración sobre el mismo proyecto Supabase de producción")

    restored: dict[str, int] = {}
    for table in TABLES:
        rows = document["tables"][table]
        if table == "adminusers":
            rows = [{**row, "refresh_token_hash": None} for row in rows]
        for position in range(0, len(rows), 100):
            batch = rows[position : position + 100]
            if not batch:
                continue
            response = requests.post(
                f"{target_url.rstrip('/')}/rest/v1/{table}",
                headers=headers(target_key, "resolution=merge-duplicates,return=minimal"),
                json=batch,
                timeout=90,
            )
            if response.status_code >= 400:
                raise BackupError(
                    f"Falló la restauración de {table} ({response.status_code}): "
                    f"{response.text[:240]}"
                )
        restored[table] = len(rows)

    sequence_response = requests.post(
        f"{target_url.rstrip('/')}/rest/v1/rpc/ecoalerta_sync_identity_sequences",
        headers=headers(target_key, "return=minimal"),
        json={},
        timeout=30,
    )
    if sequence_response.status_code >= 400:
        raise BackupError(
            "Los datos se restauraron, pero no fue posible sincronizar las secuencias. "
            "Ejecute migrations/002_operational_restore.sql en el proyecto de prueba."
        )
    return {"ok": True, "destino": "Supabase de prueba", "filas_restauradas": restored}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    backup = subparsers.add_parser("backup", help="Crear un respaldo lógico")
    backup.add_argument("--root", type=Path, required=True)
    backup.add_argument("--output", type=Path, required=True)

    validate = subparsers.add_parser("validate", help="Validar integridad y estructura")
    validate.add_argument("--input", type=Path, required=True)

    restore = subparsers.add_parser("restore", help="Restaurar en Supabase de prueba")
    restore.add_argument("--input", type=Path, required=True)
    restore.add_argument("--target-url", required=True)
    restore.add_argument("--confirm", required=True, choices=["RESTAURAR-EN-PRUEBAS"])
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "backup":
            result = create_backup(args.root.resolve(), args.output.resolve())
        elif args.command == "validate":
            document = load_and_validate(args.input.resolve())
            result = {"ok": True, "integridad": "correcta", "filas": document["row_counts"]}
        else:
            target_key = clean(os.getenv("RESTORE_SUPABASE_SERVICE_KEY"))
            if not target_key:
                raise BackupError("Falta RESTORE_SUPABASE_SERVICE_KEY para el destino de pruebas")
            result = restore_backup(
                args.input.resolve(), clean(args.target_url), target_key
            )
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (BackupError, requests.RequestException) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
