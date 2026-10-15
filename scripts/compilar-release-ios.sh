#!/usr/bin/env bash
set -Eeuo pipefail

API_BASE_URL="https://ecoalerta-neilmurillo-2026.azurewebsites.net/api"
EXPORT_METHOD="app-store"
BUILD_NAME=""
BUILD_NUMBER=""
RUN_TESTS=true

usage() {
  cat <<'USAGE'
Uso (ejecutar únicamente en macOS):
  ./scripts/compilar-release-ios.sh [opciones]

Opciones:
  --api-base-url URL       API HTTPS terminada en /api.
  --export-method METODO   app-store (predeterminado), ad-hoc,
                           development o enterprise.
  --build-name VERSION     Versión visible; por defecto usa pubspec.yaml.
  --build-number NUMERO    Número único; por defecto usa pubspec.yaml.
  --sin-pruebas             Omite analyze y test.
  -h, --help               Muestra esta ayuda.

Antes de ejecutar, abra ios/Runner.xcworkspace en Xcode y seleccione su Team
en Runner > Signing & Capabilities, con firma automática habilitada.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-base-url)
      API_BASE_URL="${2:-}"
      shift 2
      ;;
    --export-method)
      EXPORT_METHOD="${2:-}"
      shift 2
      ;;
    --build-name)
      BUILD_NAME="${2:-}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --sin-pruebas)
      RUN_TESTS=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "La firma y exportación iOS requieren macOS y Xcode." >&2
  exit 1
fi

for command_name in flutter xcodebuild xcrun codesign shasum; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $command_name" >&2
    exit 1
  fi
done

case "$EXPORT_METHOD" in
  app-store|ad-hoc|development|enterprise) ;;
  *)
    echo "Método no válido: $EXPORT_METHOD" >&2
    exit 2
    ;;
esac

if [[ ! "$API_BASE_URL" =~ ^https://.+/api/?$ ]]; then
  echo "API_BASE_URL debe usar HTTPS y terminar en /api." >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/ecoalerta-frontend/ecoalerta"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "No se encontró el proyecto Flutter: $PUBSPEC" >&2
  exit 1
fi

VERSION_LINE="$(awk '/^version:/ {print $2; exit}' "$PUBSPEC")"
if [[ ! "$VERSION_LINE" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  echo "La versión de pubspec.yaml no tiene el formato x.y.z+n." >&2
  exit 1
fi
BUILD_NAME="${BUILD_NAME:-${BASH_REMATCH[1]}}"
BUILD_NUMBER="${BUILD_NUMBER:-${BASH_REMATCH[2]}}"

cd "$PROJECT_DIR"

echo "1/6 Verificando Xcode, Flutter y configuración iOS..."
xcodebuild -version
flutter --version
flutter pub get

BUILD_SETTINGS="$(xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -showBuildSettings 2>/dev/null)"
BUNDLE_ID="$(awk -F ' = ' '/PRODUCT_BUNDLE_IDENTIFIER = / {print $2; exit}' <<<"$BUILD_SETTINGS")"
TEAM_ID="$(awk -F ' = ' '/DEVELOPMENT_TEAM = / {print $2; exit}' <<<"$BUILD_SETTINGS")"

if [[ -z "$BUNDLE_ID" || "$BUNDLE_ID" == *'$('* ]]; then
  echo "Xcode no pudo resolver el Bundle ID de Runner." >&2
  exit 1
fi
if [[ -z "$TEAM_ID" ]]; then
  echo "Falta seleccionar el Team en Runner > Signing & Capabilities de Xcode." >&2
  echo "Abra: $PROJECT_DIR/ios/Runner.xcworkspace" >&2
  exit 1
fi

echo "2/6 Validando código y pruebas..."
if [[ "$RUN_TESTS" == true ]]; then
  flutter analyze
  flutter test
else
  echo "Pruebas omitidas por solicitud explícita."
fi

ARTIFACT_DIR="$ROOT_DIR/artifacts/ios/${BUILD_NAME}+${BUILD_NUMBER}/${EXPORT_METHOD}"
SYMBOL_DIR="$ARTIFACT_DIR/symbols"
mkdir -p "$ARTIFACT_DIR" "$SYMBOL_DIR"

echo "3/6 Limpiando compilaciones anteriores..."
flutter clean
flutter pub get

echo "4/6 Creando archivo firmado y paquete IPA..."
flutter build ipa --release \
  --build-name "$BUILD_NAME" \
  --build-number "$BUILD_NUMBER" \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --export-method "$EXPORT_METHOD" \
  --obfuscate \
  --split-debug-info="$SYMBOL_DIR"

IPA_PATH="$(find build/ios/ipa -maxdepth 1 -type f -name '*.ipa' -print -quit)"
if [[ -z "$IPA_PATH" || ! -s "$IPA_PATH" ]]; then
  echo "Flutter no produjo un IPA." >&2
  exit 1
fi

OUTPUT_IPA="$ARTIFACT_DIR/EcoAlerta-${BUILD_NAME}-${BUILD_NUMBER}-${EXPORT_METHOD}.ipa"
cp "$IPA_PATH" "$OUTPUT_IPA"

echo "5/6 Verificando firma y contenido..."
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
unzip -q "$OUTPUT_IPA" -d "$TEMP_DIR"
APP_PATH="$(find "$TEMP_DIR/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "El IPA no contiene una aplicación válida." >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "6/6 Generando inventario y suma SHA-256..."
{
  echo "EcoAlerta iOS"
  echo "Versión: $BUILD_NAME ($BUILD_NUMBER)"
  echo "Bundle ID: $BUNDLE_ID"
  echo "Team ID: $TEAM_ID"
  echo "Método: $EXPORT_METHOD"
  echo "API: $API_BASE_URL"
  echo "Compilado UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "$ARTIFACT_DIR/INVENTARIO.txt"
(cd "$ARTIFACT_DIR" && shasum -a 256 "$(basename "$OUTPUT_IPA")" > SHA256SUMS.txt)

echo
echo "IPA firmado creado correctamente:"
echo "$OUTPUT_IPA"
echo "Suma SHA-256: $ARTIFACT_DIR/SHA256SUMS.txt"
if [[ "$EXPORT_METHOD" == "app-store" ]]; then
  echo "Siguiente paso: cargue el IPA con Xcode Organizer o Transporter y actívelo en TestFlight."
else
  echo "Recuerde: los dispositivos deben estar incluidos en el perfil de aprovisionamiento correspondiente."
fi
