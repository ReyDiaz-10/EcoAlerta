from fastapi.testclient import TestClient

import app.routes as routes
import app.main as main
from app.main import app


def test_health_in_test_environment():
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert "default-src 'self'" in response.headers["content-security-policy"]
    assert "https://nominatim.openstreetmap.org" in response.headers["content-security-policy"]


def test_portal_is_served_by_the_api():
    with TestClient(app) as client:
        response = client.get("/portal/")
    assert response.status_code == 200
    assert "EcoAlerta - Portal Ciudadano" in response.text
    assert 'id="btn-geocode-address"' in response.text
    assert 'id="descargar"' in response.text
    assert 'id="android-download-button"' in response.text
    assert "" in response.text


def test_portal_accepts_iphone_image_types():
    with TestClient(app) as client:
        javascript = client.get("/portal/app.js")
    assert javascript.status_code == 200
    assert "image/heic" in javascript.text
    assert "image/heif" in javascript.text


def test_android_release_manifest_matches_published_apk():
    with TestClient(app) as client:
        response = client.get("/portal/android-release.json")
    assert response.status_code == 200
    payload = response.json()
    assert payload["file_name"] == "EcoAlerta-2.3.4+6-release.apk"
    assert payload["available"] is True
    assert payload["size_bytes"] == 53168926
    assert payload["published_at"] == "2026-09-09T12:31:47.0000000Z"
    assert payload["sha256"] == "77504ed9009756268db09287e9a8d7b2f9e2258f29876b65c5e38542484488e8"
    assert payload["download_url"].startswith("https://github.com/ReyDiaz-10/EcoAlerta-Android/releases/download/")


def test_android_download_qr_is_generated_locally():
    with TestClient(app) as client:
        response = client.get("/api/distribucion/android/qr")
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert response.content.startswith(b"\x89PNG")


def test_public_lookup_requires_private_code():
    with TestClient(app) as client:
        response = client.get("/api/reportes/consulta", params={"radicado": "RAD-20260101-ABCDEF12"})
    assert response.status_code == 422


def test_admin_list_requires_authentication():
    with TestClient(app) as client:
        response = client.get("/api/reportes")
    assert response.status_code == 401


def test_admin_page_disables_cache():
    with TestClient(app) as client:
        response = client.get("/portal/admin.html")
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert 'id="dashboard-metrics"' in response.text
    assert 'id="reports-mobile"' in response.text
    assert 'id="mapa"' in response.text
    assert 'id="map-status"' in response.text
    assert 'vendor/leaflet/leaflet.js' in response.text
    assert 'unpkg.com' not in response.text


def test_admin_map_dependencies_are_served_locally():
    with TestClient(app) as client:
        javascript = client.get("/portal/vendor/leaflet/leaflet.js")
        stylesheet = client.get("/portal/vendor/leaflet/leaflet.css")
        admin_script = client.get("/portal/admin.js")
    assert javascript.status_code == 200
    assert "Leaflet" in javascript.text
    assert stylesheet.status_code == 200
    assert ".leaflet-container" in stylesheet.text
    assert admin_script.status_code == 200
    assert "coordinatesOf" in admin_script.text
    assert "geocodeHistoricalReport" in admin_script.text
    assert "refreshInFlight" in admin_script.text
    assert "reportsLoading" in admin_script.text
    assert "authorizedGetWithRetry" in admin_script.text
    assert "Archivar prueba" in admin_script.text
    assert "Eliminar definitivamente" in admin_script.text


def test_admin_can_archive_test_report(monkeypatch):
    monkeypatch.setattr(routes, "verify_admin_token", lambda _: {"sub": "administrador"})
    monkeypatch.setattr(routes, "archive_test_report", lambda filing, confirmation: {
        "success": filing == confirmation,
        "message": "Reporte archivado",
        "estado": "ARCHIVADO_PRUEBA",
    })
    with TestClient(app) as client:
        response = client.patch(
            "/api/reportes/RAD-20260905-F09F0449/archive",
            headers={"Authorization": "Bearer access-token"},
            json={"confirmacion": "RAD-20260905-F09F0449"},
        )
    assert response.status_code == 200
    assert response.json()["estado"] == "ARCHIVADO_PRUEBA"


def test_admin_can_delete_only_confirmed_archived_test_report(monkeypatch):
    monkeypatch.setattr(routes, "verify_admin_token", lambda _: {"sub": "administrador"})
    monkeypatch.setattr(routes, "delete_archived_test_report", lambda filing, confirmation: {
        "success": filing == confirmation,
        "message": "Reporte de prueba eliminado definitivamente",
    })
    with TestClient(app) as client:
        response = client.request(
            "DELETE",
            "/api/reportes/RAD-20260905-F09F0449",
            headers={"Authorization": "Bearer access-token"},
            json={"confirmacion": "RAD-20260905-F09F0449"},
        )
    assert response.status_code == 200
    assert response.json()["success"] is True


def test_admin_can_change_password_and_receives_new_session(monkeypatch):
    monkeypatch.setattr(routes, "verify_admin_token", lambda _: {"sub": "administrador"})
    monkeypatch.setattr(routes, "change_admin_password", lambda *_: True)
    monkeypatch.setattr(routes, "issue_login_tokens", lambda _: {
        "access_token": "new-access-token",
        "refresh_token": "new-refresh-token",
        "token_type": "bearer",
        "expires_in": 1800,
    })
    with TestClient(app) as client:
        response = client.post(
            "/api/admin/change-password",
            headers={"Authorization": "Bearer old-access-token"},
            json={
                "current_password": "Anterior#123",
                "new_password": "NuevaClave#456",
                "confirm_password": "NuevaClave#456",
            },
        )
    assert response.status_code == 200
    assert response.json()["access_token"] == "new-access-token"
    assert "sesiones anteriores" in response.json()["message"]


def test_untrusted_host_is_rejected():
    with TestClient(app) as client:
        response = client.get("/health", headers={"Host": "host-malicioso.example"})
    assert response.status_code == 400


def test_https_is_forced_when_enabled(monkeypatch):
    monkeypatch.setattr(main, "FORCE_HTTPS", True)
    with TestClient(app, follow_redirects=False) as client:
        response = client.get("/portal/")
    assert response.status_code == 307
    assert response.headers["location"].startswith("https://")




