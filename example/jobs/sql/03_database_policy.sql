-- 03_database_policy.sql
-- Políticas de seguridad
DO $$
BEGIN
    -- Política de inserción de ofertas
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'offers'
        AND schemaname = 'jobs'
        AND policyname = 'jobs_offers_insert_policy'
    ) THEN
        CREATE POLICY jobs_offers_insert_policy ON jobs.offers
        FOR INSERT TO authenticated
        WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Otras políticas similares...
END $$;

-- Habilitar seguridad a nivel de fila
ALTER TABLE jobs.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs.offer_applicants ENABLE ROW LEVEL SECURITY;