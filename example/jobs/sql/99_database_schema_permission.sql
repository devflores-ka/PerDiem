-- 99_database_schema_permission.sql
-- Permisos sobre las tablas principales
GRANT USAGE ON SCHEMA jobs TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA jobs TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA jobs TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA jobs TO anon, authenticated, service_role;

-- Configurar los permisos por defecto
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA jobs 
GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA jobs 
GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA jobs 
GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- Permisos para vistas
GRANT SELECT ON jobs.offers_l TO authenticated;
GRANT SELECT ON jobs.offer_applicants_l TO authenticated;