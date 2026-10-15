# 📊 Guía: Conectar EcoAlerta a PowerBI Desktop

## Resumen

La base de datos PostgreSQL de EcoAlerta (en Supabase) incluye:
- **Tabla principal**: `reportesambientales` — todos los campos de cada reporte
- **Tabla analítica**: `reports` — versión compacta para analítica rápida  
- **Vista PowerBI**: `v_reportes_powerbi` — con nombres de columnas en español y campos calculados listos para usar

---

## Paso 1 — Instalar el conector de PostgreSQL para PowerBI

PowerBI Desktop requiere el driver de PostgreSQL para conectarse a Supabase.

1. Descarga e instala **Npgsql** desde: https://github.com/npgsql/npgsql/releases  
   → Busca el instalador `.msi` de la versión más reciente
2. Reinicia PowerBI Desktop después de instalar

---

## Paso 2 — Obtener la cadena de conexión de Supabase

1. Ve a [supabase.com](https://supabase.com) y abre tu proyecto `ecoalerta`
2. En el menú lateral: **Settings → Database**
3. Copia los datos de la sección **Connection Info**:

| Campo | Ejemplo |
|---|---|
| Host | `db.xxxxxxxxxxxxxxxx.supabase.co` |
| Database name | `postgres` |
| Port | `5432` |
| User | `postgres` |
| Password | `Tu contraseña del proyecto` |

---

## Paso 3 — Conectar PowerBI a Supabase

1. Abre **PowerBI Desktop**
2. Clic en **Obtener datos** → **Más...**
3. Busca **PostgreSQL** y selecciónalo
4. Completa los campos:
   - **Servidor**: `db.xxxxxxxxxxxxxxxx.supabase.co:5432`
   - **Base de datos**: `postgres`
5. En modo de conectividad: selecciona **Importar** (recomendado) o DirectQuery
6. Ingresa usuario (`postgres`) y contraseña
7. En el Navigator, verás las tablas disponibles. Selecciona:
   - ✅ `v_reportes_powerbi` (recomendada — tiene los nombres en español)
   - ✅ `reportesambientales` (datos completos)

---

## Paso 4 — Tablas y columnas disponibles en la Vista PowerBI

La vista `v_reportes_powerbi` incluye estas columnas listas para usar en visualizaciones:

| Columna | Tipo | Uso en PowerBI |
|---|---|---|
| Radicado | Texto | ID único del reporte |
| Fecha Registro | Fecha | Eje de tiempo, segmentación por fecha |
| Color Semáforo | Texto (green/yellow/red) | Filtro de color, semáforo visual |
| Prioridad Numérica | Número (1/2/3) | Ordenamiento, gráficos de barras |
| Categoría | Texto | Filtro de categoría |
| Nivel de Peligro | Texto | Filtro, mapa de calor |
| Entidad Asignada | Texto | Gráfico por entidad |
| Origen | Texto (app/web) | Comparativa app vs web |
| Año-Mes | Texto | Serie de tiempo mensual |
| Es Válido | Booleano | Filtro de reportes válidos |
| Email Enviado | Booleano | Control de notificaciones |

---

## Paso 5 — Visualizaciones recomendadas

### 🗺️ Mapa de reportes georreferenciados
- Tipo: **Mapa** o **Mapa de ArcGIS**
- Latitud: columna `Latitud`, Longitud: columna `Longitud`
- Color: `Color Semáforo` (usando formato condicional: green=verde, yellow=amarillo, red=rojo)

### 📊 Reportes por categoría
- Tipo: **Gráfico de barras**
- Eje X: `Categoría`, Eje Y: `COUNT(Radicado)`
- Segmentación por `Color Semáforo`

### 📈 Evolución temporal
- Tipo: **Gráfico de líneas**
- Eje X: `Año-Mes`, Eje Y: `COUNT(Radicado)`
- Leyenda: `Nivel de Peligro`

### 🏢 Por entidad asignada
- Tipo: **Gráfico de pastel** o **Treemap**
- Grupos: `Entidad Asignada`, Valores: `COUNT(*)`

### 🚦 Semáforo de prioridad
- Tipo: **Medidor** o **KPI**  
- Valor: `SUM(Prioridad Numérica)`, Objetivo: total de reportes × 1 (todos verdes)

---

## Paso 6 — Actualización automática de datos

Para que PowerBI se actualice automáticamente con los nuevos reportes:

1. **Publica** el reporte en **PowerBI Service** (powerbi.com)
2. Configura una **Puerta de enlace de datos** (Data Gateway) si usas modo Importar
3. O usa **DirectQuery** para ver datos en tiempo real sin gateway

---

## Consulta SQL personalizada (opcional)

Si quieres escribir una consulta SQL personalizada en PowerBI:

```sql
-- Reportes de las últimas 4 semanas por color
SELECT
    color                        AS "Color",
    COUNT(*)                     AS "Total",
    DATE_TRUNC('week', fecha_registro) AS "Semana"
FROM reportesambientales
WHERE fecha_registro >= NOW() - INTERVAL '4 weeks'
GROUP BY color, DATE_TRUNC('week', fecha_registro)
ORDER BY "Semana" DESC, "Total" DESC;

-- Distribución por entidad y categoría
SELECT 
    entidad_assigned             AS "Entidad",
    categoria                    AS "Categoría",
    COUNT(*)                     AS "Reportes",
    SUM(CASE WHEN color='red' THEN 1 ELSE 0 END) AS "Críticos"
FROM reportesambientales
WHERE es_valido = TRUE
GROUP BY entidad_assigned, categoria
ORDER BY "Reportes" DESC;

-- Búsqueda por palabra clave
SELECT radicado, fecha_registro, descripcion_ciudadano, color
FROM reportesambientales
WHERE descripcion_ciudadano ILIKE '%basura%'
   OR descripcion_ia ILIKE '%basura%'
ORDER BY fecha_registro DESC;
```

---

## Soporte

- Documentación Supabase: https://supabase.com/docs  
- Documentación PowerBI PostgreSQL: https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-data-sources
