# EcoAlerta Flutter 2.3.2

Cliente compartido para Android, iOS y web. La URL del backend se fija durante
la compilación y nunca contiene credenciales:

```bash
flutter run --dart-define="API_BASE_URL=https://servidor.example/api"
```

Funciones conservadas en ambas plataformas móviles: reporte con descripción y
prioridad, ubicación GPS y mapa manual, hasta cinco fotografías, análisis IA,
radicado+código privado, consulta de estado, PDF, sugerencias, privacidad y
llamada de emergencia.

Para Android consulte `../../PUBLICACION_ANDROID.md`. Para iPhone/iPad consulte
`../../PUBLICACION_IOS.md`; el IPA firmado solo puede generarse en macOS con
Xcode y una identidad Apple Developer.
