-- 04_storage.sql
-- Insertar bucket de storage de manera segura
INSERT INTO storage.buckets (id, name, public)
VALUES ('jobs_offers_images', 'jobs_offers_images', true)
ON CONFLICT (id) DO UPDATE
SET public = true;

-- Eliminar políticas existentes para evitar duplicados
DROP POLICY IF EXISTS jobs_images_upload_policy ON storage.objects;
DROP POLICY IF EXISTS jobs_images_read_policy ON storage.objects;
DROP POLICY IF EXISTS jobs_images_update_policy ON storage.objects;
DROP POLICY IF EXISTS jobs_images_delete_policy ON storage.objects;

-- Políticas de storage
-- Política para subir imágenes
CREATE POLICY jobs_images_upload_policy ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'jobs_offers_images' AND 
    auth.uid() IS NOT NULL
);

-- Política para leer imágenes (acceso público)
CREATE POLICY jobs_images_read_policy ON storage.objects
FOR SELECT TO anon, authenticated
USING (bucket_id = 'jobs_offers_images');

-- Política para actualizar imágenes
CREATE POLICY jobs_images_update_policy ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id = 'jobs_offers_images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Política para eliminar imágenes
CREATE POLICY jobs_images_delete_policy ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'jobs_offers_images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);