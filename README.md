# EcoAlerta 🌿

**Plataforma para la gestión inteligente de reportes ciudadanos sobre situaciones urbanas y ambientales.**

EcoAlerta permite registrar situaciones que afectan el entorno urbano mediante una descripción, ubicación geográfica y evidencia fotográfica. Incorpora capacidades de inteligencia artificial para apoyar el análisis, la clasificación y la sugerencia de direccionamiento de los reportes.

> **Estado del proyecto:** aplicación Android funcional. Algunas capacidades, integraciones y elementos de distribución pueden encontrarse en desarrollo o sujetos a validación según la versión publicada.

## 📌 Tabla de contenido

- [Descripción](#-descripción)
- [Objetivos](#-objetivos)
- [Funcionalidades](#-funcionalidades)
- [Categorías de reportes](#-categorías-de-reportes)
- [Arquitectura y tecnologías](#-arquitectura-y-tecnologías)
- [Estructura del repositorio](#-estructura-del-repositorio)
- [Instalación y ejecución](#-instalación-y-ejecución)
- [Configuración](#-configuración)
- [Compilación y firma de Android](#-compilación-y-firma-de-android)
- [Distribución mediante GitHub Releases](#-distribución-mediante-github-releases)
- [Seguridad y privacidad](#-seguridad-y-privacidad)
- [Hoja de ruta](#-hoja-de-ruta)
- [Contribuciones](#-contribuciones)
- [Licencia](#-licencia)
- [Contacto](#-contacto)

## 🌱 Descripción

EcoAlerta es un proyecto tecnológico enfocado en facilitar el registro y la gestión de reportes ciudadanos relacionados con problemas ambientales y situaciones que afectan la infraestructura y los espacios públicos.

La solución busca estructurar la información recibida para que pueda analizarse de forma más organizada. La inteligencia artificial sirve como apoyo al proceso de validación y clasificación; sus recomendaciones no deben interpretarse automáticamente como una decisión oficial de una entidad pública.

EcoAlerta es una iniciativa independiente. La publicación del proyecto no implica afiliación, aprobación ni integración oficial con la Alcaldía de Medellín u otra entidad pública.

## 🎯 Objetivos

- Facilitar el registro de situaciones por parte de la ciudadanía.
- Asociar los reportes con ubicación geográfica y evidencia fotográfica.
- Apoyar la validación y clasificación mediante inteligencia artificial.
- Sugerir una posible categoría o entidad responsable para revisión.
- Mejorar la consulta y el seguimiento de los reportes.
- Ofrecer herramientas administrativas para revisar información y consultar su trazabilidad.
- Explorar oportunidades de interoperabilidad institucional mediante pruebas y acuerdos formales.

## ✨ Funcionalidades

Las funciones disponibles pueden variar según la versión instalada y la configuración del entorno.

- **Registro ciudadano:** descripción de la situación reportada.
- **Evidencia fotográfica:** adjuntar una fotografía al reporte.
- **Geolocalización:** asociar una ubicación al caso cuando esté disponible y autorizada.
- **Análisis asistido por IA:** apoyar la validación y clasificación del contenido recibido.
- **Sugerencia de direccionamiento:** proponer una categoría o posible entidad competente para revisión.
- **Generación de reportes:** organizar los datos del caso y generar una referencia o documento cuando esté habilitado.
- **Panel administrativo:** consultar reportes y apoyar su revisión.
- **Trazabilidad:** visualizar el estado y los cambios registrados, de acuerdo con las funciones habilitadas.
- **Mapa de reportes:** visualizar casos georreferenciados cuando el mapa y los datos estén disponibles.
- **Exportación y descarga:** consultar o descargar reportes mediante las opciones habilitadas en la versión correspondiente.

> La clasificación de la IA puede contener errores. Los reportes y las entidades sugeridas deben revisarse antes de usarse para tomar decisiones operativas.

## 🏙️ Categorías de reportes

Según la configuración de la aplicación, EcoAlerta contempla situaciones como:

- Huecos sobre la vía.
- Separadores viales deteriorados.
- Ocupación de espacios públicos, parques o zonas verdes.
- Puntos críticos de acumulación de residuos.
- Inundaciones o desbordamientos de basuras en quebradas, canales o caños.
- Escombros en vías públicas.
- Ausencia de contenedores de residuos.
- Contenedores de residuos dañados.
- Ciclorrutas obstruidas o en mal estado.
- Vehículos abandonados.

Las categorías, reglas de clasificación y entidades sugeridas pueden cambiar según las necesidades del proyecto.

## 🧰 Arquitectura y tecnologías

La arquitectura exacta debe documentarse de acuerdo con el código y la versión que se publiquen en este repositorio.

| Componente | Descripción |
|---|---|
| Aplicación móvil | Aplicación para Android. |
| Identificador Android | `com.ecoalerta.app` |
| Inteligencia artificial | Análisis asistido por IA, según la configuración del entorno. |
| Servicios y backend | Documentar el framework, los servicios y las versiones que realmente utilice el proyecto. |
| Persistencia de datos | Documentar el motor y la configuración utilizados en la versión publicada. |
| Panel administrativo | Interfaz para consultar y gestionar reportes, según las funciones disponibles. |

**Antes de publicar:** reemplaza las descripciones pendientes por las tecnologías verificadas en el código. No publiques direcciones privadas, credenciales ni detalles de infraestructura que puedan comprometer el sistema.

## 📁 Estructura del repositorio

La estructura real depende de cómo esté organizado el proyecto. Este ejemplo es orientativo; ajusta los nombres a las carpetas que subas:

```text
EcoAlerta/
├── android/                 # Código Android (si aplica)
├── backend/                 # API y servicios del servidor (si aplica)
├── web/                     # Interfaz web o panel administrativo (si aplica)
├── docs/                    # Documentación y capturas no sensibles
├── .gitignore
├── .env.example             # Ejemplo sin secretos, si aplica
└── README.md
```

No crees carpetas vacías solo para que coincidan con este ejemplo. Documenta la estructura que realmente exista.

## 🚀 Instalación y ejecución

### Opción A: instalar una versión publicada

Cuando exista una versión pública disponible, descarga el APK desde **Releases** o desde la página oficial de descarga de EcoAlerta.

1. Descarga el archivo APK publicado.
2. Verifica que proceda del enlace oficial.
3. Si Android lo solicita, autoriza la instalación para la aplicación desde la que abriste el archivo.
4. Completa la instalación y abre EcoAlerta.

Android puede advertir sobre aplicaciones instaladas fuera de Google Play. Habilita ese permiso únicamente cuando sea necesario y para la fuente de confianza correspondiente.

### Opción B: obtener el código fuente

```bash
git clone https://github.com/USUARIO/REPOSITORIO.git
cd REPOSITORIO
```

Sustituye `USUARIO/REPOSITORIO` por la dirección real cuando el repositorio esté creado.

Después, sigue las instrucciones específicas de cada componente. Los comandos de compilación deben añadirse una vez confirmadas la estructura y las herramientas utilizadas. Documenta por separado los pasos verificados para Android, backend y web, si corresponden.

## ⚙️ Configuración

Si el proyecto utiliza variables de entorno, crea un archivo local a partir de una plantilla como `.env.example` y completa los valores en tu entorno de desarrollo.

Ejemplo orientativo —no representa una lista confirmada de variables del proyecto—:

```dotenv
# Completar solo con los nombres de variables que use el código.
# No incluyas valores reales ni credenciales en este archivo.
API_BASE_URL=
AI_API_KEY=
DATABASE_URL=
```

- Mantén `.env` fuera del control de versiones.
- No guardes claves en el código fuente ni en archivos de configuración públicos.
- Si una clave se publica accidentalmente, revócala y genera una nueva.
- Documenta las variables requeridas sin revelar sus valores.

## 🤖 Compilación y firma de Android

El identificador de aplicación previsto es:

```text
com.ecoalerta.app
```

Para publicar una actualización compatible con una instalación existente:

1. Conserva el mismo identificador de aplicación.
2. Firma la nueva versión con la misma clave de firma utilizada para la versión instalada.
3. Incrementa el `versionCode` de Android.
4. Comprueba la instalación y actualización en un dispositivo de prueba.
5. Verifica que la versión publicada y el APK correspondan al mismo artefacto probado.

Nombre de archivo previsto para la versión mencionada:

```text
EcoAlerta-2.3.2+4-release.apk
```

Este nombre no confirma por sí solo que el APK esté firmado, probado o publicado. Comprueba el archivo real antes de distribuirlo.

**Importante:** realiza una copia de seguridad segura del keystore y sus contraseñas. No los subas al repositorio ni los adjuntes en incidencias públicas.

## 📦 Distribución mediante GitHub Releases

GitHub Releases permite publicar versiones y adjuntar el APK como archivo descargable.

1. Crea el repositorio y configura sus reglas de seguridad.
2. Genera y prueba el APK firmado.
3. Calcula el tamaño y el hash SHA-256 del archivo exacto que se publicará.
4. Crea un Release con una etiqueta de versión clara.
5. Adjunta `EcoAlerta-2.3.2+4-release.apk`.
6. Publica notas de versión, requisitos y cambios.
7. Enlaza la descarga desde la página pública oficial de EcoAlerta.

No inventes el tamaño, la fecha de publicación ni el hash: obtén esos datos del APK final.

En Windows, calcula SHA-256 con PowerShell:

```powershell
Get-FileHash .\EcoAlerta-2.3.2+4-release.apk -Algorithm SHA256
```

La página pública de descarga debería mostrar:

- Versión.
- Tamaño del archivo.
- Fecha de publicación.
- Hash SHA-256.
- Botón de descarga.
- Instrucciones de instalación.
- Política de privacidad.
- Enlace a las notas de la versión.

## 🔐 Seguridad y privacidad

La seguridad de la información ciudadana es prioritaria. Antes de publicar el código:

- **No subas API keys, tokens, contraseñas ni archivos `.env`.**
- **No subas el keystore de Android ni sus contraseñas.**
- No publiques bases de datos de producción, reportes reales, fotografías de usuarios, coordenadas privadas ni datos personales.
- No incluyas credenciales de correo, cadenas de conexión ni certificados privados.
- Usa datos ficticios en capturas, pruebas y documentación pública.
- Revisa el historial de Git: borrar un secreto del último commit no garantiza que desaparezca del historial.
- Si se expone un secreto, revócalo y reemplázalo inmediatamente.
- Limita los permisos administrativos y protege los servicios que procesan reportes.
- Publica una política de privacidad accesible que explique qué información se recoge, con qué finalidad, cómo se procesa, cuánto tiempo se conserva y cómo solicitar su eliminación, según corresponda.
- Solicita permisos del dispositivo de forma transparente y utiliza la ubicación y las fotografías conforme a la finalidad informada al usuario.

Este README no sustituye una revisión de seguridad ni una política de privacidad legalmente revisada.

## 🗺️ Hoja de ruta

Estas tareas son objetivos de evolución; no implican que ya estén implementadas:

- [ ] Mejorar la adaptación del panel administrativo a móviles y tabletas.
- [ ] Facilitar el acceso al mapa y la consulta de reportes en pantallas pequeñas.
- [ ] Revisar la accesibilidad de los colores de prioridad y estado.
- [ ] Verificar y completar las opciones de descarga y exportación de reportes.
- [ ] Publicar una página pública de descarga de Android en el dominio oficial.
- [ ] Automatizar o documentar el proceso de publicación de versiones.
- [ ] Documentar la arquitectura, configuración y despliegue reales.
- [ ] Revisar seguridad, privacidad y manejo de datos antes de ampliar la distribución.
- [ ] Evaluar posibles integraciones con entidades o sistemas externos mediante autorización y pruebas formales.

## 🤝 Contribuciones

Las sugerencias, reportes de errores y propuestas de mejora son bienvenidos.

Al abrir una incidencia, describe:

- Qué intentabas hacer.
- Qué ocurrió y qué esperabas que ocurriera.
- Pasos para reproducir el problema.
- Versión de EcoAlerta y dispositivo/entorno, cuando sea relevante.
- Capturas sin datos personales ni información sensible.

No publiques secretos, información de usuarios, fotografías privadas ni detalles que faciliten atacar sistemas. Para reportar una vulnerabilidad, utiliza un canal privado que el mantenedor haya habilitado.

## 📄 Licencia

La licencia del proyecto debe definirse antes de permitir formalmente su reutilización o redistribución.

**Licencia actual: por definir.**

Hasta que se agregue un archivo `LICENSE` y se indique aquí la licencia elegida, no asumas que el código puede copiarse, modificarse o redistribuirse libremente.

## 📬 Contacto

- **Proyecto:** EcoAlerta
- **Responsable:** [Nombre del responsable o equipo]
- **Correo:** [Correo de contacto del proyecto]
- **Sitio web:** [Dominio oficial, cuando esté configurado]
- **Incidencias:** utiliza la pestaña *Issues* de este repositorio, si está habilitada.

---

<p align="center">
  <strong>EcoAlerta</strong><br>
  Tecnología para organizar información ciudadana y apoyar la gestión de situaciones urbanas y ambientales.
</p>
