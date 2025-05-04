-- 03_database_policy.sql
-- Habilitar seguridad a nivel de fila en todas las tablas
ALTER TABLE jobs.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs.offer_applicants ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs.habilidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs.habilidades_usuario ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes para evitar duplicados
DROP POLICY IF EXISTS jobs_offers_insert_policy ON jobs.offers;
DROP POLICY IF EXISTS jobs_offers_select_policy ON jobs.offers;
DROP POLICY IF EXISTS jobs_offers_update_policy ON jobs.offers;
DROP POLICY IF EXISTS jobs_offers_delete_policy ON jobs.offers;

DROP POLICY IF EXISTS jobs_applicants_insert_policy ON jobs.offer_applicants;
DROP POLICY IF EXISTS jobs_applicants_select_policy ON jobs.offer_applicants; 
DROP POLICY IF EXISTS jobs_applicants_delete_policy ON jobs.offer_applicants;

DROP POLICY IF EXISTS jobs_habilidades_usuario_insert_policy ON jobs.habilidades_usuario;
DROP POLICY IF EXISTS jobs_habilidades_usuario_select_policy ON jobs.habilidades_usuario;
DROP POLICY IF EXISTS jobs_habilidades_usuario_update_policy ON jobs.habilidades_usuario;
DROP POLICY IF EXISTS jobs_habilidades_usuario_delete_policy ON jobs.habilidades_usuario;

-- Políticas para la tabla de ofertas
CREATE POLICY jobs_offers_insert_policy ON jobs.offers
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY jobs_offers_select_policy ON jobs.offers
    FOR SELECT TO authenticated
    USING (true); -- Todos pueden ver todas las ofertas

CREATE POLICY jobs_offers_update_policy ON jobs.offers
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY jobs_offers_delete_policy ON jobs.offers
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- Políticas para la tabla de postulantes
CREATE POLICY jobs_applicants_insert_policy ON jobs.offer_applicants
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY jobs_applicants_select_policy ON jobs.offer_applicants
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id OR 
           auth.uid() IN (SELECT user_id FROM jobs.offers WHERE id = offer_id));

CREATE POLICY jobs_applicants_delete_policy ON jobs.offer_applicants
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- Políticas para categorías (lectura pública, administración restringida)
CREATE POLICY jobs_categories_select_policy ON jobs.categories
    FOR SELECT TO authenticated
    USING (true);

-- Políticas para habilidades (lectura pública)
CREATE POLICY jobs_habilidades_select_policy ON jobs.habilidades
    FOR SELECT TO authenticated
    USING (true);

-- Políticas para habilidades de usuario
CREATE POLICY jobs_habilidades_usuario_insert_policy ON jobs.habilidades_usuario
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY jobs_habilidades_usuario_select_policy ON jobs.habilidades_usuario
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id OR true); -- El usuario puede ver sus propias habilidades y otros pueden verlas también

CREATE POLICY jobs_habilidades_usuario_update_policy ON jobs.habilidades_usuario
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY jobs_habilidades_usuario_delete_policy ON jobs.habilidades_usuario
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);