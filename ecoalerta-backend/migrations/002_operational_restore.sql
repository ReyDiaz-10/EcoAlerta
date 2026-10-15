-- EcoAlerta 2.3 - soporte seguro para restauraciones lógicas.
-- Ejecute en el proyecto Supabase de PRUEBAS después de 001_production.sql.

begin;

create or replace function public.ecoalerta_sync_identity_sequences()
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  perform setval(
    pg_get_serial_sequence('public.reportesambientales', 'id_reporte'),
    greatest(coalesce((select max(id_reporte) from public.reportesambientales), 1), 1),
    exists(select 1 from public.reportesambientales)
  );
  perform setval(
    pg_get_serial_sequence('public.adminusers', 'id'),
    greatest(coalesce((select max(id) from public.adminusers), 1), 1),
    exists(select 1 from public.adminusers)
  );
  perform setval(
    pg_get_serial_sequence('public.feedback', 'id'),
    greatest(coalesce((select max(id) from public.feedback), 1), 1),
    exists(select 1 from public.feedback)
  );
  perform setval(
    pg_get_serial_sequence('public.entityresponses', 'id'),
    greatest(coalesce((select max(id) from public.entityresponses), 1), 1),
    exists(select 1 from public.entityresponses)
  );
end;
$$;

revoke all on function public.ecoalerta_sync_identity_sequences() from public, anon, authenticated;
grant execute on function public.ecoalerta_sync_identity_sequences() to service_role;

commit;
