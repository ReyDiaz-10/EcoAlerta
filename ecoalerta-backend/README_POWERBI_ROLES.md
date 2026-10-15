Power BI & Roles — EcoAlerta

Resumen rápido
- La aplicación almacena reportes en Supabase / PostgreSQL (proyecto: `ecoalerta`).
- Se crearon tablas y una vista optimizada para facilitar conexión con Power BI:
  - `reportesambientales` — tabla histórica con todos los detalles del reporte.
  - `reports` — tabla analítica compacta para Power BI.
  - `entityresponses` — respuestas de entidades vinculadas a reportes.
  - `feedback` — sugerencias y comentarios ciudadanos.
  - `v_reportes_powerbi` — vista optimizada para Power BI con nombres en español y cálculos listos.

Conexión Power BI (pasos mínimos)
- En Power BI Desktop: `Get Data` -> `PostgreSQL database`.
  - Server: `db.[PROJECT-REF].supabase.co`
  - Database: `postgres`
  - User: `postgres`
  - Password: la contraseña de base de datos de Supabase.
- Usa SSL/TLS y, si Power BI lo solicita, instala el driver PostgreSQL compatible (Npgsql).
- Selecciona principalmente la vista `v_reportes_powerbi`.
- Para análisis adicional, también puedes cargar las tablas `reportesambientales`, `reports`, `entityresponses` y `feedback`.

Visuales recomendados
- Mapa: `latitud`, `longitud`, color por `Color Semáforo`.
- Series temporales: `Fecha Registro` y `Año-Mes`.
- Segmentaciones: `Color Semáforo`, `Nivel de Peligro`, `Categoría`, `Entidad Asignada`.
- Tablas / matrices: `Radicado`, `Entidad Asignada`, `Tipo de Problema`, `Descripcion IA`.

Esquema mínimo recomendado (columnas clave)
- `reportesambientales`: `id_reporte`, `radicado`, `radicado_original`, `fecha_registro`, `descripcion_ciudadano`, `direccion_declarada`, `latitud`, `longitud`, `categoria`, `tipo_problema`, `nivel_peligro`, `color`, `prioridad`, `entidad_destino`, `descripcion_ia`, `email_enviado`, `es_valido`.
- `reports`: `id`, `radicado`, `radicado_original`, `source_platform`, `creation_date`, `latitude`, `longitude`, `status`, `descripcion`, `direccion`, `prioridad`, `tipo_problema`, `nivel_peligro`, `color`, `entidad_destino`, `descripcion_ia`.
- `entityresponses`: `id`, `report_id`, `response_date`, `entity_name`, `response_text`, `filing_number`.
- `feedback`: `id`, `created_at`, `nombre`, `correo`, `mensaje`, `tipo`.

Roles y portal web
- Portal Público (ciudadano):
  - Buscar por `radicado` y palabras clave.
  - Descargar PDF del radicado en `/api/reportes/{radicado}/download`.
  - Enviar sugerencias/quejas en `feedback`.
- Panel de Administración (admin):
  - Login admin con JWT.
  - Filtros por `status`, `color`, `entidad_destino`.
  - Gestión de respuestas oficiales en `entityresponses`.

Siguientes pasos recomendados
1. Verificar que `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY` y `DATABASE_URL` estén definidos en `.env`.
2. Arrancar el backend con `uvicorn app.main:app`.
3. Enviar un reporte de prueba y confirmar que aparece en Supabase Studio.
4. Buscar el reporte desde el frontend y descargar el PDF.
5. Conectar Power BI a la vista `v_reportes_powerbi`.

