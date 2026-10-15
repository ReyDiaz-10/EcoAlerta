import io

from PIL import Image

import pytest
from pydantic import ValidationError

import app.services as services
from app.schemas import AdminPasswordChangeRequest, AdminReportActionRequest, SuggestionRequest
from app.services import ensure_ia_response_fields, validate_and_normalize_images


def image_bytes() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (40, 30), "#2e7d32").save(output, "PNG")
    return output.getvalue()


def heic_bytes() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (40, 30), "#2e7d32").save(output, "HEIF", quality=90)
    return output.getvalue()


def test_image_validation_normalizes_to_jpeg():
    result = validate_and_normalize_images([
        {"filename": "evidencia.png", "content": image_bytes(), "content_type": "image/png"}
    ])
    assert result[0]["content_type"] == "image/jpeg"
    assert len(result[0]["sha256"]) == 64


def test_iphone_heic_image_normalizes_to_jpeg():
    result = validate_and_normalize_images([
        {"filename": "IMG_0001.HEIC", "content": heic_bytes(), "content_type": "image/heic"}
    ])
    assert result[0]["content_type"] == "image/jpeg"
    with Image.open(io.BytesIO(result[0]["content"])) as normalized:
        assert normalized.format == "JPEG"


def test_fallback_analysis_requires_manual_review():
    result = ensure_ia_response_fields({})
    assert result["valido"] is False
    assert result["entidad_destino"] == "NINGUNA"
    assert result["color"] == "yellow"


def test_suggestion_accepts_legacy_english_fields():
    payload = SuggestionRequest.model_validate({
        "citizen_name": "Ana",
        "citizen_email": "ana@example.com",
        "message_type": "sugerencia",
        "content": "Más contenedores en el parque",
    })
    assert payload.nombre == "Ana"
    assert payload.mensaje.startswith("Más")


def test_admin_password_change_requires_strong_matching_password():
    payload = AdminPasswordChangeRequest.model_validate({
        "current_password": "Anterior#123",
        "new_password": "NuevaClave#456",
        "confirm_password": "NuevaClave#456",
    })
    assert payload.new_password == "NuevaClave#456"

    with pytest.raises(ValidationError):
        AdminPasswordChangeRequest.model_validate({
            "current_password": "Anterior#123",
            "new_password": "solo-minusculas",
            "confirm_password": "no-coincide-123",
        })


def test_admin_report_action_normalizes_filing_number():
    payload = AdminReportActionRequest.model_validate({"confirmacion": "  rad-20260905-f09f0449  "})
    assert payload.confirmacion == "RAD-20260905-F09F0449"


def test_archive_test_report_changes_status(monkeypatch):
    monkeypatch.setattr(services, "get_report", lambda *_args, **_kwargs: {"estado": "EN_REVISION"})
    monkeypatch.setattr(services, "update_report", lambda filing, values: [{"radicado": filing, **values}])
    result = services.archive_test_report("RAD-20260905-F09F0449", "RAD-20260905-F09F0449")
    assert result["estado"] == "ARCHIVADO_PRUEBA"


def test_delete_test_report_requires_prior_archive(monkeypatch):
    monkeypatch.setattr(services, "get_report", lambda *_args, **_kwargs: {"estado": "EN_REVISION"})
    with pytest.raises(Exception) as exc:
        services.delete_archived_test_report("RAD-20260905-F09F0449", "RAD-20260905-F09F0449")
    assert getattr(exc.value, "status_code", None) == 409
