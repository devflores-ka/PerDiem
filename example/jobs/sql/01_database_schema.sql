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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla intermedia de postulantes
CREATE TABLE IF NOT EXISTS jobs.offer_applicants (
    offer_id BIGINT NOT NULL REFERENCES jobs.offers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (offer_id, user_id)
);