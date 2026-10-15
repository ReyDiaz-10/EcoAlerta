from __future__ import annotations

import hashlib
import hmac
import io
import json
import os
import re
import secrets
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from email_validator import EmailNotValidError, validate_email
from fastapi import HTTPException
from google.genai import types
from google.genai.types import Part
from PIL import Image, ImageOps, UnidentifiedImageError
from pillow_heif import register_heif_opener

from .auth import create_analysis_token, verify_analysis_token
from .config import (
    ALLOW_TEST_MODE,
    CARPETA_INFORMES,
    CLIENT,
    DICCIONARIO_CORREOS_ENTIDADES,
    DICCIONARIO_ENTIDADES,
    EMAIL_DELIVERY_ENABLED,
    GENAI_MODEL_NAMES,
    MAX_IMAGE_PIXELS,
    PUBLIC_BASE_URL,
    TEST_RECIPIENT_EMAIL,
)
from .db import (
    DatabaseError,
    create_feedback,
    delete_report,
    delete_report_timeline,
    get_metrics,
    get_report,
    insert_report,
    list_reports,
    report_timeline,
    update_report,
)
from .pdf_mail import enviar_correo_reporte, generar_pdf_reporte


register_heif_opener(thumbnails=False)
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS

DEFAULT_IA_KEYS = {
    "valido": False,
    "categoria": "NO_DETERMINADO",
    "subcategoria": "Revisión requerida",
    "tipo_problema": "Problema no determinado",
    "nivel_peligro": "medio",
    "color": "yellow",
    "prioridad": "yellow",
    "entidad_destino": "NINGUNA",
    "justificacion": "El reporte requiere revisión humana antes de su envío.",
    "evaluacion_riesgo": "Pendiente de evaluación manual.",
    "descripcion_ia": "No fue posible completar un análisis visual fiable.",
}

ALLOWED_IMAGE_FORMATS = {"JPEG", "JPG", "PNG", "WEBP", "HEIF", "HEIC"}
ALLOWED_COLORS = {"green", "yellow", "red"}
ALLOWED_DANGER = {"bajo", "medio", "alto"}


def build_system_prompt() -> str:
    entities = ", ".join(DICCIONARIO_ENTIDADES.keys() - {"NINGUNA"})
    return f"""
Actúa como clasificador de apoyo para EcoAlerta Medellín y Valle de Aburrá.
Analiza únicamente la evidencia visible. No inventes ubicaciones, causas ni
responsables. Marca valido=false cuando la imagen sea irrelevante, interior,
un meme, una selfie, esté inutilizable o no muestre un incidente identificable.

Categorías admitidas: AMBIENTAL, INFRAESTRUCTURA_VIAL,
ESPACIO_PUBLICO_ASEO. Colores: green=bajo, yellow=medio, red=alto.
Entidades admitidas: {entities}.

Devuelve exclusivamente JSON con estas claves:
valido, categoria, subcategoria, tipo_problema, nivel_peligro, color,
prioridad, entidad_destino, justificacion, evaluacion_riesgo, descripcion_ia.
""".strip()


def _normalize_image(payload: Dict[str, object]) -> Dict[str, object]:
    content = payload.get("content")
    if not isinstance(content, (bytes, bytearray)) or not content:
        raise HTTPException(status_code=400, detail="Se recibió una imagen vacía")
    raw = bytes(content)
    try:
        with Image.open(io.BytesIO(raw)) as source:
            source.verify()
        with Image.open(io.BytesIO(raw)) as source:
            detected_format = str(source.format or "").upper()
            if detected_format not in ALLOWED_IMAGE_FORMATS:
                raise HTTPException(status_code=400, detail="Formato de imagen no permitido")
            image = ImageOps.exif_transpose(source).convert("RGB")
            image.thumbnail((2048, 2048))
            output = io.BytesIO()
            image.save(output, format="JPEG", quality=85, optimize=True)
            normalized = output.getvalue()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="El archivo adjunto no es una imagen válida") from exc
    return {
        "filename": Path(str(payload.get("filename") or "evidencia.jpg")).name,
        "content": normalized,
        "content_type": "image/jpeg",
        "sha256": hashlib.sha256(normalized).hexdigest(),
    }


def validate_and_normalize_images(image_payloads: List[Dict[str, object]]) -> List[Dict[str, object]]:
    if not image_payloads:
        raise HTTPException(status_code=400, detail="Debe adjuntar al menos una imagen")
    return [_normalize_image(payload) for payload in image_payloads]


def prepare_multimodal_parts(image_payloads: List[Dict[str, object]]) -> List[Part]:
    parts = [Part.from_text(text=build_system_prompt())]
    for payload in image_payloads:
        parts.append(Part.from_bytes(data=bytes(payload["content"]), mime_type="image/jpeg"))
    return parts


def parse_ia_response(text: str) -> Dict[str, object]:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return {}
    if isinstance(parsed, list):
        candidates = [item for item in parsed if isinstance(item, dict)]
        severity = {"green": 1, "yellow": 2, "red": 3}
        return max(candidates, key=lambda item: severity.get(str(item.get("color", "")).lower(), 0), default={})
    return parsed if isinstance(parsed, dict) else {}


def is_valid_ia_response(result: Dict[str, object]) -> bool:
    required = {
        "valido", "categoria", "subcategoria", "tipo_problema", "nivel_peligro",
        "color", "prioridad", "entidad_destino", "justificacion",
        "evaluacion_riesgo", "descripcion_ia",
    }
    if not isinstance(result, dict) or not required.issubset(result):
        return False
    color = str(result.get("color", "")).lower()
    danger = str(result.get("nivel_peligro", "")).lower()
    entity = str(result.get("entidad_destino", ""))
    return color in ALLOWED_COLORS and danger in ALLOWED_DANGER and entity in DICCIONARIO_ENTIDADES


def ensure_ia_response_fields(result: Dict[str, object]) -> Dict[str, object]:
    safe = {key: result.get(key, default) for key, default in DEFAULT_IA_KEYS.items()}
    safe["valido"] = safe.get("valido") is True
    safe["color"] = str(safe.get("color", "yellow")).lower()
    if safe["color"] not in ALLOWED_COLORS:
        safe["color"] = "yellow"
    safe["prioridad"] = str(safe.get("prioridad", safe["color"])).lower()
    if safe["prioridad"] not in ALLOWED_COLORS:
        safe["prioridad"] = safe["color"]
    safe["nivel_peligro"] = str(safe.get("nivel_peligro", "medio")).lower()
    if safe["nivel_peligro"] not in ALLOWED_DANGER:
        safe["nivel_peligro"] = {"green": "bajo", "yellow": "medio", "red": "alto"}[safe["color"]]
    entity = str(safe.get("entidad_destino", "NINGUNA"))
    safe["entidad_destino"] = entity if entity in DICCIONARIO_ENTIDADES else "NINGUNA"
    safe["color_asignado"] = safe["color"]
    return safe


def call_genai_model(parts: List[Part]) -> Dict[str, object]:
    if CLIENT is None:
        return {}
    for model_name in GENAI_MODEL_NAMES:
        for attempt in range(2):
            try:
                response = CLIENT.models.generate_content(
                    model=model_name,
                    contents=parts,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        temperature=0.1,
                    ),
                )
                parsed = parse_ia_response(response.text or "")
                if is_valid_ia_response(parsed):
                    return parsed
                break
            except Exception as exc:
                transient = any(code in str(exc) for code in ("429", "503", "RESOURCE_EXHAUSTED", "UNAVAILABLE"))
                if attempt == 0 and transient:
                    time.sleep(1)
                    continue
                break
    return {}


def analyze_images_preview(imagenes: List[Dict[str, object]]) -> Dict[str, object]:
    normalized = validate_and_normalize_images(imagenes)
    result = call_genai_model(prepare_multimodal_parts(normalized))
    reliable = is_valid_ia_response(result)
    analysis = ensure_ia_response_fields(result if reliable else {})
    hashes = [str(item["sha256"]) for item in normalized]
    return {
        "success": True,
        "requires_manual_review": not reliable or analysis["valido"] is not True,
        "warning": None if reliable else "La IA no está disponible; el reporte podrá enviarse a revisión humana.",
        "analisis": analysis,
        "analysis_token": create_analysis_token(hashes, analysis),
    }


def _clean_email(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    try:
        return validate_email(value, check_deliverability=False).normalized
    except EmailNotValidError as exc:
        raise HTTPException(status_code=400, detail="El correo electrónico no es válido") from exc


def _tracking_hash(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def _safe_radicado(value: str) -> str:
    value = value.strip().upper()
    if not re.fullmatch(r"RAD-[A-Z0-9-]{5,40}", value):
        raise HTTPException(status_code=400, detail="Formato de radicado inválido")
    return value


def verify_tracking_code(report: dict, code: str) -> bool:
    expected = str(report.get("consulta_token_hash") or "")
    return bool(expected and code) and hmac.compare_digest(expected, _tracking_hash(code.strip()))


def format_report_address(address: str, latitude: float, longitude: float) -> str:
    clean = " ".join(address.strip().split())
    return clean or f"Ubicación GPS: {latitude:.6f}, {longitude:.6f}"


def resolve_entity_assignment(analysis: Dict[str, object], test_mode: bool) -> Tuple[str, str, str]:
    if test_mode:
        return "Entidad de Pruebas EcoAlerta", TEST_RECIPIENT_EMAIL, "PRUEBA"
    if analysis.get("valido") is not True:
        return DICCIONARIO_ENTIDADES["NINGUNA"], "", "EN_REVISION"
    key = str(analysis.get("entidad_destino") or "NINGUNA")
    destination = DICCIONARIO_ENTIDADES.get(key, DICCIONARIO_ENTIDADES["NINGUNA"])
    email = DICCIONARIO_CORREOS_ENTIDADES.get(key, "")
    return destination, email, "CLASIFICADO" if email else "EN_REVISION"


def _write_pdf_images(images: List[Dict[str, object]], directory: str) -> List[str]:
    paths: List[str] = []
    for index, image in enumerate(images):
        path = os.path.join(directory, f"evidencia_{index + 1}.jpg")
        with open(path, "wb") as handle:
            handle.write(bytes(image["content"]))
        paths.append(path)
    return paths


def process_report_submission(
    descripcion: str,
    direccion: str,
    latitud: float,
    longitud: float,
    correo_usuario: str,
    origen: str,
    radicado_original: str,
    imagenes: List[Dict[str, object]],
    analysis_token: str = "",
    nombre_usuario: str = "",
    direccion_usuario: str = "",
    consentimiento_datos: bool = False,
) -> Dict[str, object]:
    normalized = validate_and_normalize_images(imagenes)
    hashes = [str(item["sha256"]) for item in normalized]
    if analysis_token:
        result = verify_analysis_token(analysis_token, hashes)
    else:
        result = call_genai_model(prepare_multimodal_parts(normalized))
    reliable = is_valid_ia_response(result)
    analysis = ensure_ia_response_fields(result if reliable else {})

    description = " ".join(descripcion.strip().split())
    address = format_report_address(direccion, latitud, longitud)
    citizen_email = _clean_email(correo_usuario)
    original = radicado_original.strip().upper()
    origin = origen.strip().lower()[:30] or "web"
    test_mode = ALLOW_TEST_MODE and "prueba" in description.lower()
    entity, entity_email, initial_status = resolve_entity_assignment(analysis, test_mode)

    now = datetime.now(timezone.utc)
    radicado = f"RAD-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
    tracking_code = secrets.token_urlsafe(18)
    link_maps = f"https://www.google.com/maps?q={latitud},{longitud}"

    os.makedirs(CARPETA_INFORMES, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ecoalerta-") as temp_dir:
        photo_paths = _write_pdf_images(normalized, temp_dir)
        pdf_path = generar_pdf_reporte(
            radicado=radicado,
            fecha_str=now.astimezone().strftime("%d/%m/%Y %I:%M %p"),
            entidad=entity,
            desc=description,
            dir_text=address,
            lat=latitud,
            lon=longitud,
            rutas_fotos=photo_paths,
            link_maps=link_maps,
            tipo_problema=str(analysis["tipo_problema"]),
            subcategoria=str(analysis["subcategoria"]),
            nivel_peligro=str(analysis["nivel_peligro"]),
            color=str(analysis["color"]),
            prioridad=str(analysis["prioridad"]),
            entidad_destino=str(analysis["entidad_destino"]),
            justificacion=str(analysis["justificacion"]),
            evaluacion_riesgo=str(analysis["evaluacion_riesgo"]),
            descripcion_ia=str(analysis["descripcion_ia"]),
            codigo_consulta=tracking_code,
        )

    record = {
        "radicado": radicado,
        "radicado_original": original,
        "origen": origin,
        "fecha_registro": now.isoformat(),
        "descripcion_ciudadano": description,
        "direccion_declarada": address,
        "latitud": latitud,
        "longitud": longitud,
        "correo_usuario": citizen_email,
        "nombre_usuario": " ".join(nombre_usuario.strip().split())[:120],
        "direccion_usuario": " ".join(direccion_usuario.strip().split())[:500],
        "consentimiento_datos": bool(consentimiento_datos),
        "entidad_assigned": entity,
        "correo_entidad": entity_email,
        "categoria": str(analysis["categoria"]),
        "subcategoria": str(analysis["subcategoria"]),
        "tipo_problema": str(analysis["tipo_problema"]),
        "nivel_peligro": str(analysis["nivel_peligro"]),
        "color": str(analysis["color"]),
        "prioridad": str(analysis["prioridad"]),
        "entidad_destino": str(analysis["entidad_destino"]),
        "evaluacion_riesgo": str(analysis["evaluacion_riesgo"]),
        "descripcion_ia": str(analysis["descripcion_ia"]),
        "ruta_pdf_informe": pdf_path or "",
        "link_google_maps": link_maps,
        "email_enviado": False,
        "email_intentos": 0,
        "email_error": "",
        "es_valido": analysis.get("valido") is True,
        "justificacion_ia": str(analysis["justificacion"]),
        "estado": initial_status,
        "consulta_token_hash": _tracking_hash(tracking_code),
    }
    try:
        insert_report(record)
    except DatabaseError:
        if pdf_path:
            try:
                Path(pdf_path).unlink(missing_ok=True)
            except OSError:
                pass
        raise

    mail_result = {"success": False, "attempts": 0, "error": "Envío pendiente"}
    can_deliver = EMAIL_DELIVERY_ENABLED and bool(entity_email) and analysis.get("valido") is True and bool(pdf_path)
    if can_deliver:
        mail_result = enviar_correo_reporte(
            correo_destino=entity_email,
            correo_ciudadano=citizen_email,
            radicado=radicado,
            entidad_nombre=entity,
            ruta_pdf=str(pdf_path),
        )
        update_report(
            radicado,
            {
                "email_enviado": bool(mail_result.get("success")),
                "email_intentos": int(mail_result.get("attempts") or 0),
                "email_error": str(mail_result.get("error") or ""),
                "estado": "ENVIADO_ENTIDAD" if mail_result.get("success") else "ENVIO_FALLIDO",
            },
        )

    requires_review = initial_status == "EN_REVISION"
    return {
        "success": True,
        "radicado": radicado,
        "codigo_consulta": tracking_code,
        "fecha": now.isoformat(),
        "estado": initial_status,
        "requires_manual_review": requires_review,
        "entidad_assigned": entity,
        "correo_entidad": entity_email if not requires_review else "",
        "ruta_pdf": f"{PUBLIC_BASE_URL}/api/reportes/{radicado}/download?codigo={tracking_code}" if pdf_path else "",
        "link_maps": link_maps,
        "analisis": analysis,
        "origen": origin,
        "radicado_original": original,
    }


def process_structured_report(payload) -> Dict[str, object]:
    """Mantiene operativo el endpoint JSON histórico y lo envía a revisión."""
    now = datetime.now(timezone.utc)
    radicado = f"RAD-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
    code = secrets.token_urlsafe(18)
    email = _clean_email(str(payload.citizen_email or ""))
    record = {
        "radicado": radicado,
        "origen": "api-json",
        "fecha_registro": now.isoformat(),
        "descripcion_ciudadano": payload.description,
        "direccion_declarada": payload.address,
        "latitud": payload.latitude,
        "longitud": payload.longitude,
        "correo_usuario": email,
        "nombre_usuario": "",
        "direccion_usuario": "",
        "consentimiento_datos": False,
        "entidad_assigned": DICCIONARIO_ENTIDADES["NINGUNA"],
        "categoria": payload.category,
        "subcategoria": payload.subcategory,
        "tipo_problema": payload.subcategory,
        "nivel_peligro": {"green": "bajo", "yellow": "medio", "red": "alto"}[payload.priority_color],
        "color": payload.priority_color,
        "prioridad": payload.priority_color,
        "entidad_destino": "NINGUNA",
        "evaluacion_riesgo": "Pendiente de revisión humana",
        "descripcion_ia": "Reporte recibido sin evidencia fotográfica",
        "email_enviado": False,
        "email_intentos": 0,
        "es_valido": False,
        "estado": "EN_REVISION",
        "consulta_token_hash": _tracking_hash(code),
    }
    insert_report(record)
    return {"success": True, "tracking_number": radicado, "codigo_consulta": code, "estado": "EN_REVISION"}


def store_suggestion(payload) -> dict:
    row = create_feedback(
        {"nombre": payload.nombre, "correo": str(payload.correo or ""), "mensaje": payload.mensaje, "tipo": payload.tipo}
    )
    return {"success": True, "message": "Sugerencia recibida", "id": row.get("id")}


def get_report_history(radicado_filter: Optional[str] = None, limit: int = 100, offset: int = 0) -> Dict[str, object]:
    radicado = ""
    if radicado_filter:
        candidate = radicado_filter.strip().upper()
        if not re.fullmatch(r"[A-Z0-9-]{1,45}", candidate):
            raise HTTPException(status_code=400, detail="Filtro de radicado inválido")
        radicado = candidate
    return {"success": True, "reportes": list_reports(limit=limit, offset=offset, radicado=radicado)}


def get_public_report_status(radicado: str, code: str) -> dict:
    normalized = _safe_radicado(radicado)
    full = get_report(normalized, public=False)
    if not full or not verify_tracking_code(full, code):
        raise HTTPException(status_code=404, detail="No se encontró el reporte o el código es incorrecto")
    public = get_report(normalized, public=True)
    return {"success": True, "reporte": public}


def authorize_pdf(radicado: str, code: str) -> dict:
    normalized = _safe_radicado(radicado)
    report = get_report(normalized, public=False)
    if not report or not verify_tracking_code(report, code):
        raise HTTPException(status_code=404, detail="PDF no encontrado o código incorrecto")
    return report


def get_report_detail(radicado: str) -> dict:
    normalized = _safe_radicado(radicado)
    report = get_report(normalized, public=False)
    if not report:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")
    report.pop("consulta_token_hash", None)
    return {"success": True, "detail": report, "timeline": report_timeline(normalized)}


def archive_test_report(radicado: str, confirmation: str) -> dict:
    normalized = _safe_radicado(radicado)
    if confirmation.strip().upper() != normalized:
        raise HTTPException(status_code=400, detail="La confirmación no coincide con el radicado")
    report = get_report(normalized, public=False)
    if not report:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")
    if str(report.get("estado") or "").upper() == "ARCHIVADO_PRUEBA":
        return {"success": True, "message": "El reporte ya estaba archivado", "estado": "ARCHIVADO_PRUEBA"}
    updated = update_report(normalized, {"estado": "ARCHIVADO_PRUEBA"})
    if not updated:
        raise DatabaseError("Supabase no confirmó el archivo del reporte")
    return {
        "success": True,
        "message": "Reporte archivado. Ya no se contará como pendiente de revisión.",
        "estado": "ARCHIVADO_PRUEBA",
    }


def delete_archived_test_report(radicado: str, confirmation: str) -> dict:
    normalized = _safe_radicado(radicado)
    if confirmation.strip().upper() != normalized:
        raise HTTPException(status_code=400, detail="La confirmación no coincide con el radicado")
    report = get_report(normalized, public=False)
    if not report:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")
    if str(report.get("estado") or "").upper() != "ARCHIVADO_PRUEBA":
        raise HTTPException(status_code=409, detail="Primero debe archivar el reporte como prueba")

    delete_report_timeline(normalized)
    deleted = delete_report(normalized)
    if not deleted:
        raise DatabaseError("Supabase no confirmó la eliminación del reporte")

    stored = str(report.get("ruta_pdf_informe") or "")
    if stored:
        try:
            stored_path = Path(stored).resolve()
            reports_root = Path(CARPETA_INFORMES).resolve()
            if reports_root in stored_path.parents:
                stored_path.unlink(missing_ok=True)
        except OSError:
            pass
    return {"success": True, "message": "Reporte de prueba eliminado definitivamente"}


def get_admin_metrics() -> dict:
    metrics = get_metrics()
    return {
        "success": True,
        "metrics": {
            "total_reportes": int(metrics.get("total_reportes") or 0),
            "color_green": int(metrics.get("color_green") or 0),
            "color_yellow": int(metrics.get("color_yellow") or 0),
            "color_red": int(metrics.get("color_red") or 0),
            "nivel_alto": int(metrics.get("nivel_alto") or 0),
            "nivel_medio": int(metrics.get("nivel_medio") or 0),
            "nivel_bajo": int(metrics.get("nivel_bajo") or 0),
            "email_enviados": int(metrics.get("email_enviados") or 0),
            "email_fallidos": int(metrics.get("email_fallidos") or 0),
            "email_sin_envio": int(metrics.get("email_sin_envio") or 0),
            "en_revision": int(metrics.get("en_revision") or 0),
        },
    }
