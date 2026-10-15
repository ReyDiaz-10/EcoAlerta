begin;

-- La API administrativa usa exclusivamente la clave privada service_role.
-- Se habilita DELETE para que un administrador pueda eliminar un reporte de
-- prueba solo después de archivarlo y confirmar su radicado.
grant delete on table public.entityresponses to service_role;
grant delete on table public.reportesambientales to service_role;

commit;
