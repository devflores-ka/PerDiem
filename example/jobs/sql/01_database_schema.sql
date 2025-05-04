-- 01_database_schema.sql
-- Crear el esquema para ofertas laborales
CREATE SCHEMA IF NOT EXISTS jobs;
ALTER SCHEMA jobs OWNER TO postgres;

-- Crear tabla de categorías
CREATE TABLE IF NOT EXISTS jobs.categories (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- Crear tabla de ofertas laborales
CREATE TABLE IF NOT EXISTS jobs.offers (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category_id INT NOT NULL REFERENCES jobs.categories(id) ON DELETE RESTRICT,
    amount NUMERIC(10,2) NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    location GEOGRAPHY(Point, 4326),
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla intermedia de postulantes
CREATE TABLE IF NOT EXISTS jobs.offer_applicants (
    offer_id BIGINT NOT NULL REFERENCES jobs.offers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (offer_id, user_id)
);

-- Crear tabla de habilidades laborales
CREATE TABLE IF NOT EXISTS jobs.habilidades (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla intermedia de habilidades de usuario
CREATE TABLE IF NOT EXISTS jobs.habilidades_usuario (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    habilidad_id BIGINT NOT NULL REFERENCES jobs.habilidades(id) ON DELETE CASCADE,
    nivel TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Actualizar valores existentes de latitud y longitud para registros existentes
UPDATE jobs.offers 
SET 
  latitud = ST_Y(location::geometry),
  longitud = ST_X(location::geometry)
WHERE location IS NOT NULL;

-- Crear un trigger para mantener los valores sincronizados
CREATE OR REPLACE FUNCTION update_coordinates()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.location IS NOT NULL THEN
    NEW.latitud = ST_Y(NEW.location::geometry);
    NEW.longitud = ST_X(NEW.location::geometry);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER offers_coordinates_update
BEFORE INSERT OR UPDATE ON jobs.offers
FOR EACH ROW
EXECUTE FUNCTION update_coordinates();

-- Función para contactar al propietario de una oferta
CREATE OR REPLACE FUNCTION jobs.contact_offer_owner(offer_id BIGINT, contacting_user_id UUID)
RETURNS VOID AS $$
DECLARE
    offer_owner_id UUID;
    room_id BIGINT;
BEGIN
    -- Obtener el propietario de la oferta
    SELECT user_id INTO offer_owner_id 
    FROM jobs.offers
    WHERE id = offer_id;
    
    -- Validar que el propietario existe
    IF offer_owner_id IS NULL THEN
        RAISE EXCEPTION 'La oferta no existe';
    END IF;
    
    -- Validar que el usuario no es el propietario
    IF offer_owner_id = contacting_user_id THEN
        RAISE EXCEPTION 'No puedes contactarte a ti mismo';
    END IF;
    
    -- Registrar al usuario como aplicante a la oferta
    INSERT INTO jobs.offer_applicants (offer_id, user_id)
    VALUES (offer_id, contacting_user_id)
    ON CONFLICT DO NOTHING;
    
    -- Crear una sala de chat entre el propietario y el contactante
    INSERT INTO chats.rooms (name, type, "userIds", "createdAt", "updatedAt")
    VALUES (
        'Chat de oferta #' || offer_id,
        'direct',
        ARRAY[offer_owner_id, contacting_user_id],
        EXTRACT(EPOCH FROM NOW()) * 1000,
        EXTRACT(EPOCH FROM NOW()) * 1000
    )
    RETURNING id INTO room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permiso para ejecutar la función
GRANT EXECUTE ON FUNCTION jobs.contact_offer_owner TO authenticated;