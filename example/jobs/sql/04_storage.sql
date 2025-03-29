-- 04_storage.sql
-- Insertar bucket de storage de manera segura
INSERT INTO storage.buckets (id, name)
VALUES ('jobs_offers_images', 'jobs_offers_images')
ON CONFLICT (id) DO NOTHING;

-- Políticas de storage
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage'
        AND policyname = 'jobs_images_upload_policy'
    ) THEN
        CREATE POLICY jobs_images_upload_policy ON storage.objects
        FOR INSERT TO authenticated
        WITH CHECK (bucket_id = 'jobs_offers_images' AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage'
        AND policyname = 'jobs_images_read_policy'
    ) THEN
        CREATE POLICY jobs_images_read_policy ON storage.objects
        FOR SELECT TO authenticated
        USING (bucket_id = 'jobs_offers_images');
    END IF;
END $$;
