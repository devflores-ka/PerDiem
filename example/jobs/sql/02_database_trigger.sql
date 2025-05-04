-- 02_database_trigger.sql
-- Función de trigger para registrar postulantes automáticamente
CREATE OR REPLACE FUNCTION jobs.auto_register_applicant()
RETURNS TRIGGER AS $$
BEGIN
    -- Registra automáticamente al creador de la oferta como postulante
    INSERT INTO jobs.offer_applicants (offer_id, user_id)
    VALUES (NEW.id, NEW.user_id)
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Eliminar el trigger si ya existe para evitar conflictos
DROP TRIGGER IF EXISTS trigger_auto_register_applicant ON jobs.offers;

-- Crear el trigger
CREATE TRIGGER trigger_auto_register_applicant
AFTER INSERT ON jobs.offers
FOR EACH ROW 
EXECUTE FUNCTION jobs.auto_register_applicant();