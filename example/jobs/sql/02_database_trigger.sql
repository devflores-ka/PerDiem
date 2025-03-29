-- 02_database_trigger.sql
-- Función de trigger para registrar postulantes automáticamente
CREATE OR REPLACE FUNCTION jobs.auto_register_applicant()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO jobs.offer_applicants (offer_id, user_id)
    VALUES (NEW.id, NEW.user_id)
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger solo si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.triggers 
        WHERE event_object_table = 'offers'
        AND trigger_schema = 'jobs'
        AND trigger_name = 'trigger_auto_register_applicant'
    ) THEN
        CREATE TRIGGER trigger_auto_register_applicant
        AFTER INSERT ON jobs.offers
        FOR EACH ROW EXECUTE FUNCTION jobs.auto_register_applicant();
    END IF;
END $$;