from pathlib import Path

import app.integration_check as integration_check


def test_ai_check_reports_missing_key(monkeypatch, tmp_path):
    image = tmp_path / "evidencia.jpg"
    image.write_bytes(b"imagen")
    monkeypatch.setattr(integration_check, "GENAI_API_KEY", "")

    result = integration_check.check_ai(image)

    assert result["ok"] is False
    assert "GENAI_API_KEY" in result["error"]


def test_ai_check_reports_real_classification(monkeypatch, tmp_path):
    image = tmp_path / "evidencia.png"
    image.write_bytes(b"imagen")
    monkeypatch.setattr(integration_check, "GENAI_API_KEY", "clave-configurada")
    monkeypatch.setattr(integration_check, "GENAI_MODEL_NAMES", "gemini-2.5-flash")
    monkeypatch.setattr(
        integration_check,
        "analyze_images_preview",
        lambda _: {
            "requires_manual_review": False,
            "warning": None,
            "analisis": {
                "valido": True,
                "categoria": "RESIDUOS",
                "subcategoria": "Acumulacion de residuos",
                "tipo_problema": "Basura en espacio publico",
                "nivel_peligro": "MEDIO",
                "color": "orange",
                "entidad_destino": "Entidad ambiental",
                "descripcion_ia": "Residuos visibles junto a la via.",
            },
        },
    )

    result = integration_check.check_ai(image)

    assert result["ok"] is True
    assert result["resultado"]["categoria"] == "RESIDUOS"
    assert "clave-configurada" not in str(result)


def test_email_check_requires_explicit_delivery(monkeypatch):
    monkeypatch.setattr(integration_check, "EMAIL_DELIVERY_ENABLED", False)

    result = integration_check.check_email("prueba@example.com")

    assert result["ok"] is False
    assert "EMAIL_DELIVERY_ENABLED" in result["error"]


def test_email_check_sends_only_to_test_destination(monkeypatch):
    captured = {}
    monkeypatch.setattr(integration_check, "EMAIL_DELIVERY_ENABLED", True)
    monkeypatch.setattr(integration_check, "SMTP_SERVER", "smtp.example.com")
    monkeypatch.setattr(integration_check, "SMTP_PORT", 587)
    monkeypatch.setattr(integration_check, "CORREO_EMISOR", "ecoalerta@example.com")

    def fake_send(**kwargs):
        captured.update(kwargs)
        assert Path(kwargs["ruta_pdf"]).is_file()
        return {"success": True, "attempts": 1, "error": None}

    monkeypatch.setattr(integration_check, "enviar_correo_reporte", fake_send)

    result = integration_check.check_email("destino@example.com")

    assert result["ok"] is True
    assert result["destino"] == "destino@example.com"
    assert captured["correo_destino"] == "destino@example.com"
    assert captured["correo_ciudadano"] == ""
