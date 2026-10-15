"""Rutas HTTP públicas y administrativas de EcoAlerta."""

from __future__ import annotations

from pathlib import Path
from io import BytesIO
from typing import List

import anyio
from fastapi import APIRouter, File, Form, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import FileResponse, Response

from .auth import (
    authenticate_admin,
    issue_login_tokens,
    revoke_session,
    rotate_refresh_token,
    verify_admin_token,
    verify_refresh_token,
)
from .config import MAX_IMAGE_BYTES, MAX_IMAGES, MAX_TOTAL_UPLOAD_BYTES, REPORTS_DIR
from .db import DatabaseError
from .schemas import (
    AdminLoginRequest,
    AdminPasswordChangeRequest,
    AdminReportActionRequest,
    LogoutRequest,
    RefreshRequest,
    ReportRequest,
    SuggestionRequest,
)
from .users import change_admin_password
from .services import (
    analyze_images_preview,
    archive_test_report,
    authorize_pdf,
    delete_archived_test_report,
    get_admin_metrics,
    get_public_report_status,
    get_report_detail,
    get_report_history,
    process_report_submission,
    process_structured_report,
    store_suggestion,
)

router = APIRouter()
ALLOWED_UPLOAD_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}
ALLOWED_UPLOAD_SUFFIXES = {
    ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif",
}


@router.get("/distribucion/android/qr", include_in_schema=False)
async def android_download_qr(request: Request):
    """Código QR estable hacia la sección oficial de descarga del portal."""
    import qrcode

    portal_url = str(request.base_url).rstrip("/") + "/portal/#descargar"
    image = await anyio.to_thread.run_sync(lambda: qrcode.make(portal_url))
    output = BytesIO()
    image.save(output, format="PNG")
    return Response(
        content=output.getvalue(),
        media_type="image/png",
        headers={"Cache-Control": "public, max-age=86400", "Content-Disposition": "inline"},
    )


def _get_bearer_token(request: Request, *, required: bool = True) -> str:
    auth = request.headers.get("authorization", "")
    if auth.lower().startswith("bearer "):
        return auth.split(None, 1)[1]
    if required:
        raise HTTPException(status_code=401, detail="Autenticación requerida")
    return ""


async def _read_images(images: List[UploadFile]) -> list[dict]:
    if not images:
        raise HTTPException(status_code=400, detail="Debe adjuntar al menos una imagen")
    if len(images) > MAX_IMAGES:
        raise HTTPException(status_code=400, detail=f"Máximo {MAX_IMAGES} imágenes permitidas")

    total = 0
    payload: list[dict] = []
    for index, image in enumerate(images):
        media_type = (image.content_type or "").lower()
        filename = Path(image.filename or f"imagen_{index + 1}").name
        suffix = Path(filename).suffix.lower()
        if media_type not in ALLOWED_UPLOAD_TYPES and suffix not in ALLOWED_UPLOAD_SUFFIXES:
            raise HTTPException(
                status_code=415,
                detail="Solo se permiten imágenes JPEG, PNG, WebP, HEIC o HEIF",
            )
        chunks: list[bytes] = []
        size = 0
        while chunk := await image.read(256 * 1024):
            size += len(chunk)
            total += len(chunk)
            if size > MAX_IMAGE_BYTES:
                raise HTTPException(status_code=413, detail=f"La imagen {index + 1} supera el tamaño permitido")
            if total > MAX_TOTAL_UPLOAD_BYTES:
                raise HTTPException(status_code=413, detail="El conjunto de imágenes supera el tamaño permitido")
            chunks.append(chunk)
        payload.append({
            "filename": filename,
            "content": b"".join(chunks),
            "content_type": media_type,
        })
        await image.close()
    return payload


def _service_unavailable() -> HTTPException:
    return HTTPException(status_code=503, detail="Servicio temporalmente no disponible")


def _verify_admin_request(request: Request) -> dict:
    try:
        return verify_admin_token(_get_bearer_token(request))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/suggestions", status_code=status.HTTP_201_CREATED)
async def create_suggestion(payload: SuggestionRequest):
    try:
        return await anyio.to_thread.run_sync(lambda: store_suggestion(payload))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/reports", status_code=status.HTTP_201_CREATED)
async def create_report(payload: ReportRequest):
    try:
        return await anyio.to_thread.run_sync(lambda: process_structured_report(payload))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/reportes", status_code=status.HTTP_201_CREATED)
async def recibir_y_clasificar_reporte(
    descripcion: str = Form(..., min_length=3, max_length=3000),
    direccion: str = Form("", max_length=500),
    latitud: float = Form(..., ge=-90, le=90),
    longitud: float = Form(..., ge=-180, le=180),
    correo_usuario: str = Form("", max_length=320),
    nombre_usuario: str = Form("", max_length=120),
    direccion_usuario: str = Form("", max_length=500),
    consentimiento_datos: bool = Form(...),
    origen: str = Form("web", max_length=30),
    radicado_original: str = Form("", max_length=50),
    analysis_token: str = Form("", max_length=8192),
    imagenes: List[UploadFile] = File(...),
):
    if not consentimiento_datos:
        raise HTTPException(status_code=400, detail="Debe aceptar el tratamiento de datos")
    image_payload = await _read_images(imagenes)
    try:
        return await anyio.to_thread.run_sync(lambda: process_report_submission(
            descripcion=descripcion,
            direccion=direccion,
            latitud=latitud,
            longitud=longitud,
            correo_usuario=correo_usuario,
            nombre_usuario=nombre_usuario,
            direccion_usuario=direccion_usuario,
            consentimiento_datos=consentimiento_datos,
            origen=origen,
            radicado_original=radicado_original,
            imagenes=image_payload,
            analysis_token=analysis_token,
        ))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/reportes/analizar-previa")
async def analizar_reporte_previo(imagenes: List[UploadFile] = File(...)):
    image_payload = await _read_images(imagenes)
    return await anyio.to_thread.run_sync(lambda: analyze_images_preview(image_payload))


@router.get("/reportes")
async def obtener_historico_reportes(
    request: Request,
    radicado: str = Query("", max_length=45),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    _verify_admin_request(request)
    try:
        return await anyio.to_thread.run_sync(lambda: get_report_history(radicado, limit, offset))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.get("/reportes/consulta")
async def consultar_estado_publico(
    radicado: str = Query(..., min_length=8, max_length=45),
    codigo: str = Query(..., min_length=10, max_length=200),
):
    try:
        return await anyio.to_thread.run_sync(lambda: get_public_report_status(radicado, codigo))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/admin/login")
async def admin_login(payload: AdminLoginRequest):
    try:
        authenticated = await anyio.to_thread.run_sync(lambda: authenticate_admin(payload.username, payload.password))
        if not authenticated:
            raise HTTPException(status_code=401, detail="Credenciales inválidas")
        return await anyio.to_thread.run_sync(lambda: issue_login_tokens(payload.username))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/admin/refresh")
async def admin_refresh(payload: RefreshRequest):
    try:
        return await anyio.to_thread.run_sync(lambda: rotate_refresh_token(payload.refresh_token))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.post("/admin/logout", status_code=status.HTTP_204_NO_CONTENT)
async def admin_logout(payload: LogoutRequest):
    token_data = verify_refresh_token(payload.refresh_token)
    username = str(token_data.get("sub") or "")
    if username:
        try:
            await anyio.to_thread.run_sync(lambda: revoke_session(username))
        except DatabaseError as exc:
            raise _service_unavailable() from exc
    return None


@router.post("/admin/change-password")
async def admin_change_password(payload: AdminPasswordChangeRequest, request: Request):
    token_data = _verify_admin_request(request)
    username = str(token_data.get("sub") or "")
    try:
        changed = await anyio.to_thread.run_sync(
            lambda: change_admin_password(username, payload.current_password, payload.new_password)
        )
        if not changed:
            raise HTTPException(status_code=400, detail="La contraseña actual es incorrecta")
        tokens = await anyio.to_thread.run_sync(lambda: issue_login_tokens(username))
        return {"message": "Contraseña actualizada. Las sesiones anteriores fueron cerradas.", **tokens}
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.get("/admin/metrics")
async def admin_metrics(request: Request):
    _verify_admin_request(request)
    try:
        return await anyio.to_thread.run_sync(get_admin_metrics)
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.get("/reportes/{radicado}/detail")
async def obtener_detalle_reporte(radicado: str, request: Request):
    _verify_admin_request(request)
    try:
        return await anyio.to_thread.run_sync(lambda: get_report_detail(radicado))
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.patch("/reportes/{radicado}/archive")
async def archivar_reporte_de_prueba(
    radicado: str,
    payload: AdminReportActionRequest,
    request: Request,
):
    _verify_admin_request(request)
    try:
        return await anyio.to_thread.run_sync(
            lambda: archive_test_report(radicado, payload.confirmacion)
        )
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.delete("/reportes/{radicado}")
async def eliminar_reporte_de_prueba(
    radicado: str,
    payload: AdminReportActionRequest,
    request: Request,
):
    _verify_admin_request(request)
    try:
        return await anyio.to_thread.run_sync(
            lambda: delete_archived_test_report(radicado, payload.confirmacion)
        )
    except DatabaseError as exc:
        raise _service_unavailable() from exc


@router.get("/reportes/{radicado}/download")
async def descargar_pdf_radicado(radicado: str, request: Request, codigo: str = Query("", max_length=200)):
    try:
        token = _get_bearer_token(request, required=False)
        if token:
            verify_admin_token(token)
            report = (await anyio.to_thread.run_sync(lambda: get_report_detail(radicado)))["detail"]
        else:
            if not codigo:
                raise HTTPException(status_code=401, detail="Código de consulta requerido")
            report = await anyio.to_thread.run_sync(lambda: authorize_pdf(radicado, codigo))
    except DatabaseError as exc:
        raise _service_unavailable() from exc

    stored = str(report.get("ruta_pdf_informe") or "")
    path = Path(stored).resolve() if stored else (REPORTS_DIR / f"{radicado}.pdf").resolve()
    reports_root = REPORTS_DIR.resolve()
    if reports_root not in path.parents or not path.is_file():
        raise HTTPException(status_code=404, detail="PDF no encontrado")
    return FileResponse(path, media_type="application/pdf", filename=f"{radicado}.pdf")
