# EcoAlerta 🌿

[![Live Portal](https://img.shields.io/badge/Portal_Web-Azure_Live-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://ecoalerta-neilmurillo-2026.azurewebsites.net/portal/)
[![Demo Institucional](https://img.shields.io/badge/Demo_Institucional-Interactive_Site-2EA44F?style=for-the-badge)](https://ecoalerta-demo-institucional.nsernafigueroa.chatgpt.site/)
[![Latest Release](https://img.shields.io/badge/Download_APK-v2.3.2-blue?style=for-the-badge&logo=android&logoColor=white)](https://github.com/ReyDiaz-10/EcoAlerta/releases)

> 🚀 **Demos en vivo:**
> - 🌐 **Portal Ciudadano Principal:** [Ver Portal en Azure](https://ecoalerta-neilmurillo-2026.azurewebsites.net/portal/)
> - 🏛️ **Demo Institucional:** [Explorar Demo](https://ecoalerta-demo-institucional.nsernafigueroa.chatgpt.site/)

**Plataforma para la gestión inteligente de reportes ciudadanos sobre situaciones urbanas y ambientales.**

EcoAlerta permite registrar situaciones que afectan el entorno urbano mediante una descripción, ubicación geográfica y evidencia fotográfica. Incorpora capacidades de inteligencia artificial para apoyar el análisis, la clasificación y la sugerencia de direccionamiento de los reportes.

> **Estado del proyecto:** aplicación Android funcional. Algunas capacidades, integraciones y elementos de distribución pueden encontrarse en desarrollo o sujetos a validación según la versión publicada.

## 📌 Tabla de contenido

- [Descripción](#-descripción)
- [Objetivos](#-objetivos)
- [Funcionalidades](#-funcionalidades)
- [Categorías de reportes](#-categorías-de-reportes)
- [Arquitectura y tecnologías](#-arquitectura-y-tecnologías)
- [Instalación y ejecución](#-instalación-y-ejecución)
- [Compilación y firma de Android](#-compilación-y-firma-de-android)
- [Distribución mediante GitHub Releases](#-distribución-mediante-github-releases)
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

## 🏗️ Arquitectura del Sistema

EcoAlerta está diseñado como un ecosistema integral bajo una arquitectura Cliente-Servidor impulsada por IA. El núcleo del sistema es una API centralizada que da servicio a múltiples plataformas frontend y delega el análisis de datos a modelos de lenguaje avanzado, todo desplegado en la nube.

```mermaid
graph TD
    %% Nodos de interfaz de usuario
    App[📱 App Móvil<br/>Flutter / Dart]
    Web[💻 Portal Web<br/>Panel Administrativo]

    %% Nodo del backend
    API(⚙️ Backend API REST<br/>FastAPI / Python)

    %% Nodos de procesamiento y datos
    DB[(🗄️ Base de Datos)]
    IA[🧠 Inteligencia Artificial<br/>Google Gemini API]
    Cloud((☁️ Microsoft Azure))

    %% Relaciones
    App <==>|Peticiones HTTP/JSON| API
    Web <==>|Peticiones HTTP/JSON| API
    API <==>|Lectura / Escritura| DB
    API <==>|Clasificación y Análisis| IA
    API -.->|Despliegue y Hosting| Cloud

    %% Estilos
    style App fill:#42a5f5,stroke:#0d47a1,stroke-width:2px,color:#fff
    style Web fill:#42a5f5,stroke:#0d47a1,stroke-width:2px,color:#fff
    style API fill:#66bb6a,stroke:#1b5e20,stroke-width:2px,color:#fff
    style DB fill:#ffa726,stroke:#e65100,stroke-width:2px,color:#fff
    style IA fill:#ab47bc,stroke:#4a148c,stroke-width:2px,color:#fff
    style Cloud fill:#26c6da,stroke:#006064,stroke-width:2px,color:#fff



## 🚀 Instalación y ejecución

### instalar una versión publicada

Cuando exista una versión pública disponible, descarga el APK desde **Releases** o desde la página oficial de descarga de EcoAlerta.

1. Descarga el archivo APK publicado.
2. Verifica que proceda del enlace oficial.
3. Si Android lo solicita, autoriza la instalación para la aplicación desde la que abriste el archivo.
4. Completa la instalación y abre EcoAlerta.

Android puede advertir sobre aplicaciones instaladas fuera de Google Play. Habilita ese permiso únicamente cuando sea necesario y para la fuente de confianza correspondiente.


## 🤖 Compilación y firma de Android

El identificador de aplicación previsto es:

```text
com.ecoalerta.app
```


```text
EcoAlerta-2.3.2.6-release.apk
```

## 📦 Distribución mediante GitHub Releases

GitHub Releases permite publicar versiones y adjuntar el APK como archivo descargable.

1. Crea el repositorio y configura sus reglas de seguridad.
2. Genera y prueba el APK firmado.
3. Calcula el tamaño y el hash SHA-256 del archivo exacto que se publicará.
4. Crea un Release con una etiqueta de versión clara.
5. Adjunta `EcoAlerta-2.3.2+6-release.apk`.
6. Publica notas de versión, requisitos y cambios.
7. Enlaza la descarga desde la página pública oficial de EcoAlerta.

https://ecoalerta-neilmurillo-2026.azurewebsites.net/portal/

## 📬 Contacto

- **Proyecto:** EcoAlerta
- **Responsable:** Neil Farith Murillo Díaz
- **Correo:** neildiazusb@gmail.com/neilmurillodiaz@outlook.com
- **Sitio web:** https://ecoalerta-neilmurillo-2026.azurewebsites.net/portal/

<p align="center">
  <strong>EcoAlerta</strong><br>
  Tecnología para organizar información ciudadana y apoyar la gestión de situaciones urbanas y ambientales.
</p>
