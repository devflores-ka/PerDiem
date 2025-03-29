-- 05_database_views.sql
-- Vista de ofertas laborales
CREATE OR REPLACE VIEW jobs.offers_l AS
SELECT o.id,
       o.user_id,
       u."firstName" AS created_by_first_name,
       u."lastName" AS created_by_last_name,
       o.name AS offer_name,
       c.name AS category_name,
       o.amount,
       o.description,
       o.image_url,
       o.location,
       o.created_at
FROM jobs.offers o
JOIN chats.users u ON u.id = o.user_id
JOIN jobs.categories c ON c.id = o.category_id;

-- Vista de postulantes a ofertas laborales
CREATE OR REPLACE VIEW jobs.offer_applicants_l AS
SELECT oa.offer_id,
       oa.user_id,
       u."firstName" AS applicant_first_name,
       u."lastName" AS applicant_last_name,
       o.name AS offer_name,
       oa.applied_at
FROM jobs.offer_applicants oa
JOIN chats.users u ON u.id = oa.user_id
JOIN jobs.offers o ON o.id = oa.offer_id;