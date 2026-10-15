"""Prueba local de Gemini y SMTP sin exponer credenciales."""

from __future__ import annotations

import argparse
import json
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from email_validator import EmailNotValidError, validate_email
from fpdf import FPDF

from .config import (
    CORREO_EMISOR,
    EMAIL_DELIVERY_ENABLED,
    GENAI_API_KEY,
    GENAI_MODEL_NAMES,
    SMTP_PORT,
    SMTP_SERVER,
)
from .pdf_mail import enviar_correo_reporte
from .services import analyze_images_preview


ALLOWED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def _test_pdf(path: Path) -> None:
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", style="B", size=16)
    pdf.cell(0, 12, "EcoAlerta - prueba controlada de correo", align="C")
    pdf.ln(18)
    pdf.set_font("Helvetica", size=11)
    pdf.multi_cell(
        0,
        7,
        "Este mensaje confirma que la configuracion SMTP de EcoAlerta puede "
        "enviar un informe PDF. No corresponde a un reporte ciudadano real.",
    )
    pdf.output(path)


def check_ai(image_path: Path) -> dict:
    if not GENAI_API_KEY:
        return {
            "ok": False,
            "error": "GENAI_API_KEY no está configurada en ecoalerta-backend/.env",
        }
    try:
        result = analyze_images_preview([{
            "filename": image_path.name,
            "content": image_path.read_bytes(),
            "content_type": "image/jpeg",
        }])
        analysis = result.get("analisis") if isinstance(result.get("analisis"), dict) else {}
        ai_used = result.get("warning") is None and analysis.get("categoria") != "NO_DETERMINADO"
        return {
            "ok": ai_used,
            "modelos": GENAI_MODEL_NAMES,
            "requiere_revision_manual": result.get("requires_manual_review"),
            "resultado": {
                "valido": analysis.get("valido"),
                "categoria": analysis.get("categoria"),
                "subcategoria": analysis.get("subcategoria"),
                "tipo_problema": analysis.get("tipo_problema"),
                "nivel_peligro": analysis.get("nivel_peligro"),
                "color": analysis.get("color"),
                "entidad_destino": analysis.get("entidad_destino"),
                "descripcion": analysis.get("descripcion_ia"),
            },
            "error": None if ai_used else (
                "Gemini no produjo una clasificación válida. Revise la clave, la cuota y el modelo."
            ),
        }
    except Exception as exc:
        return {"ok": False, "error": f"{type(exc).__name__}: {str(exc)[:240]}"}


def check_email(destination: str) -> dict:
    if not EMAIL_DELIVERY_ENABLED:
        return {
            "ok": False,
            "error": "EMAIL_DELIVERY_ENABLED debe estar en true para realizar la prueba.",
        }
    if not (SMTP_SERVER and CORREO_EMISOR):
        return {"ok": False, "error": "La configuración SMTP está incompleta."}
    try:
        destination = validate_email(destination, check_deliverability=False).normalized
    except EmailNotValidError:
        return {"ok": False, "error": "El correo de prueba no tiene un formato válido."}

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    with tempfile.TemporaryDirectory(prefix="ecoalerta-test-") as temp_dir:
        pdf_path = Path(temp_dir) / f"PRUEBA-CORREO-{timestamp}.pdf"
        _test_pdf(pdf_path)
        result = enviar_correo_reporte(
            correo_destino=destination,
            correo_ciudadano="",
            radicado=f"PRUEBA-{timestamp}",
            entidad_nombre="Diagnóstico controlado EcoAlerta",
            ruta_pdf=str(pdf_path),
        )
    return {
        "ok": result.get("success") is True,
        "servidor": SMTP_SERVER,
        "puerto": SMTP_PORT,
        "remitente_configurado": bool(CORREO_EMISOR),
        "destino": destination,
        "intentos": result.get("attempts"),
        "error": result.get("error"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Prueba Gemini y correo de EcoAlerta")
    parser.add_argument("--imagen", required=True, help="Ruta de una fotografía JPEG, PNG o WebP")
    parser.add_argument("--correo", required=True, help="Correo que recibirá el mensaje de prueba")
    args = parser.parse_args()

    image_path = Path(args.imagen).expanduser().resolve()
    if not image_path.is_file() or image_path.suffix.lower() not in ALLOWED_SUFFIXES:
        print(json.dumps({"error": "La imagen no existe o no tiene un formato permitido."}, ensure_ascii=False))
        return 2

    result = {
        "inteligencia_artificial": check_ai(image_path),
        "correo": check_email(args.correo),
    }
    result["resultado_general"] = all(section.get("ok") is True for section in result.values())
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["resultado_general"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
