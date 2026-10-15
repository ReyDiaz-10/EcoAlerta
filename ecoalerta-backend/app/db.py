"""Acceso a Supabase mediante PostgREST.

Las migraciones viven en ``migrations/`` y nunca se ejecutan al arrancar la
API. La clave de servicio se usa únicamente en el servidor.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

import requests

from .config import SUPABASE_SERVICE_KEY, SUPABASE_URL


class DatabaseError(RuntimeError):
    pass


def _headers(prefer: str = "return=representation") -> Dict[str, str]:
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Content-Type": "application/json",
        "Prefer": prefer,
    }
    # Las nuevas claves sb_secret_ no son JWT y deben viajar solo en apikey.
    # Las claves service_role heredadas siguen necesitando Bearer.
    if not SUPABASE_SERVICE_KEY.startswith("sb_secret_"):
        headers["Authorization"] = f"Bearer {SUPABASE_SERVICE_KEY}"
    return headers


def _request(
    method: str,
    resource: str,
    *,
    params: Optional[Dict[str, str]] = None,
    json_body: Any = None,
    timeout: int = 20,
    prefer: str = "return=representation",
) -> requests.Response:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise DatabaseError("Supabase no está configurado")
    response = requests.request(
        method,
        f"{SUPABASE_URL.rstrip('/')}/rest/v1/{resource.lstrip('/')}",
        headers=_headers(prefer),
        params=params,
        json=json_body,
        timeout=timeout,
    )
    if response.status_code >= 400:
        raise DatabaseError(f"Supabase respondió {response.status_code}: {response.text[:300]}")
    return response


def select_rows(
    table: str,
    *,
    select: str = "*",
    filters: Optional[Dict[str, str]] = None,
    order: Optional[str] = None,
    limit: Optional[int] = None,
    offset: Optional[int] = None,
) -> List[dict]:
    params: Dict[str, str] = {"select": select}
    if filters:
        params.update(filters)
    if order:
        params["order"] = order
    if limit is not None:
        params["limit"] = str(limit)
    if offset is not None:
        params["offset"] = str(offset)
    response = _request("GET", table, params=params, prefer="count=exact")
    data = response.json()
    return data if isinstance(data, list) else []


def insert_row(table: str, payload: dict) -> dict:
    response = _request("POST", table, json_body=payload)
    data = response.json()
    if not isinstance(data, list) or not data:
        raise DatabaseError(f"Supabase no confirmó la inserción en {table}")
    return data[0]


def update_rows(table: str, filters: Dict[str, str], payload: dict) -> List[dict]:
    response = _request("PATCH", table, params=filters, json_body=payload)
    data = response.json() if response.text else []
    return data if isinstance(data, list) else []


def delete_rows(table: str, filters: Dict[str, str]) -> List[dict]:
    response = _request("DELETE", table, params=filters, prefer="return=representation")
    data = response.json() if response.text else []
    return data if isinstance(data, list) else []


def healthcheck() -> bool:
    select_rows("reportesambientales", select="id_reporte", limit=1)
    return True


REPORT_LIST_FIELDS = (
    "id_reporte,radicado,radicado_original,origen,fecha_registro,"
    "descripcion_ciudadano,direccion_declarada,latitud,longitud,correo_usuario,"
    "nombre_usuario,direccion_usuario,consentimiento_datos,"
    "entidad_assigned,correo_entidad,categoria,subcategoria,tipo_problema,"
    "nivel_peligro,color,prioridad,entidad_destino,evaluacion_riesgo,descripcion_ia,"
    "ruta_pdf_informe,link_google_maps,email_enviado,email_intentos,email_error,"
    "es_valido,justificacion_ia,estado"
)

PUBLIC_REPORT_FIELDS = (
    "radicado,radicado_original,origen,fecha_registro,entidad_assigned,categoria,"
    "subcategoria,tipo_problema,nivel_peligro,color,prioridad,evaluacion_riesgo,"
    "descripcion_ia,es_valido,estado"
)


def insert_report(payload: dict) -> dict:
    return insert_row("reportesambientales", payload)


def update_report(radicado: str, payload: dict) -> List[dict]:
    return update_rows("reportesambientales", {"radicado": f"eq.{radicado}"}, payload)


def delete_report(radicado: str) -> List[dict]:
    return delete_rows("reportesambientales", {"radicado": f"eq.{radicado}"})


def delete_report_timeline(radicado: str) -> List[dict]:
    return delete_rows("entityresponses", {"filing_number": f"eq.{radicado}"})


def get_report(radicado: str, *, public: bool = False) -> Optional[dict]:
    rows = select_rows(
        "reportesambientales",
        select=PUBLIC_REPORT_FIELDS if public else REPORT_LIST_FIELDS + ",consulta_token_hash",
        filters={"radicado": f"eq.{radicado}"},
        limit=1,
    )
    return rows[0] if rows else None


def list_reports(*, limit: int = 100, offset: int = 0, radicado: str = "") -> List[dict]:
    filters = {"radicado": f"ilike.*{radicado}*"} if radicado else None
    return select_rows(
        "reportesambientales",
        select=REPORT_LIST_FIELDS,
        filters=filters,
        order="fecha_registro.desc",
        limit=min(max(limit, 1), 200),
        offset=max(offset, 0),
    )


def report_timeline(radicado: str) -> List[dict]:
    return select_rows(
        "entityresponses",
        select="response_date,entity_name,response_text,attachments",
        filters={"filing_number": f"eq.{radicado}"},
        order="response_date.asc",
        limit=200,
    )


def create_feedback(payload: dict) -> dict:
    return insert_row("feedback", payload)


def get_metrics() -> dict:
    response = _request("POST", "rpc/ecoalerta_metrics", json_body={})
    data = response.json()
    if isinstance(data, list) and data:
        return data[0]
    if isinstance(data, dict):
        return data
    return {}


def get_admin(username: str) -> Optional[dict]:
    rows = select_rows(
        "adminusers",
        filters={"username": f"eq.{username}"},
        limit=1,
    )
    return rows[0] if rows else None


def create_admin(payload: dict) -> dict:
    return insert_row("adminusers", payload)


def update_admin(username: str, payload: dict) -> List[dict]:
    return update_rows("adminusers", {"username": f"eq.{username}"}, payload)
