USE master;
GO

-- LEGADO SQL Server: no lo use para la instalación actual (usa Supabase).
-- Si conserva una integración antigua, reemplace la clave y guárdela en un
-- administrador de secretos. Nunca conceda db_owner a la cuenta de la app.
CREATE LOGIN buzon_web_user WITH PASSWORD = 'REEMPLAZAR-POR-UNA-CLAVE-SEGURA';
GO

USE BuzonAmbiental;
GO

-- 2. Creamos el usuario dentro de tu base de datos del proyecto
CREATE USER buzon_web_user FOR LOGIN buzon_web_user;
GO

-- Conceda únicamente SELECT/INSERT/UPDATE sobre las tablas estrictamente
-- necesarias para esa integración, por ejemplo:
-- GRANT SELECT, INSERT, UPDATE ON dbo.ReportesAmbientales TO buzon_web_user;
GO
