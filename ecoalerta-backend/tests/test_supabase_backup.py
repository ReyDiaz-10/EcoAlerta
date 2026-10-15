import gzip
import hashlib
import json

import pytest


SAMPLE_TABLES = {
    "reportesambientales": [{"id_reporte": 1, "radicado": "ECO-1"}],
    "adminusers": [{"id": 1, "username": "admin", "refresh_token_hash": "x"}],
    "feedback": [],
    "entityresponses": [],
}


def _module():
    import importlib.util
    from pathlib import Path

    script = Path(__file__).parents[2] / "scripts" / "supabase_backup.py"
    spec = importlib.util.spec_from_file_location("supabase_backup", script)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(module)
    return module


def _write_backup(path, module, tables=SAMPLE_TABLES):
    document = {
        "format": "ecoalerta-supabase-logical-backup",
        "format_version": 1,
        "created_at": "2026-01-01T00:00:00+00:00",
        "source_url_sha256": module.source_hash("https://prod.supabase.co"),
        "migration_sha256": "abc",
        "payload_sha256": hashlib.sha256(module.stable_json(tables)).hexdigest(),
        "row_counts": {name: len(rows) for name, rows in tables.items()},
        "tables": tables,
    }
    with gzip.open(path, "wt", encoding="utf-8") as handle:
        json.dump(document, handle)


def test_validate_backup_checks_integrity(tmp_path):
    module = _module()
    path = tmp_path / "backup.json.gz"
    _write_backup(path, module)

    result = module.load_and_validate(path)

    assert result["row_counts"]["reportesambientales"] == 1


def test_validate_backup_rejects_tampering(tmp_path):
    module = _module()
    path = tmp_path / "backup.json.gz"
    _write_backup(path, module)
    with gzip.open(path, "rt", encoding="utf-8") as handle:
        document = json.load(handle)
    document["tables"]["feedback"].append({"id": 9})
    with gzip.open(path, "wt", encoding="utf-8") as handle:
        json.dump(document, handle)

    with pytest.raises(module.BackupError, match="SHA-256"):
        module.load_and_validate(path)


def test_restore_rejects_production_target(tmp_path):
    module = _module()
    path = tmp_path / "backup.json.gz"
    _write_backup(path, module)

    with pytest.raises(module.BackupError, match="producción"):
        module.restore_backup(path, "https://prod.supabase.co", "sb_secret_test")
