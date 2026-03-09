-- Corrigir feed_photos: usar business_date (America/Sao_Paulo) em vez de UTC
-- Depende de 20260215_business_timezone_helpers.sql

CREATE OR REPLACE VIEW feed_photos AS
SELECT
  p.id,
  p.user_id,
  p.image_url,
  p.thumbnail_url,
  p.score,
  p.recado,
  p.is_shared,
  p.likes_count,
  p.comments_count,
  p.created_at,
  p.updated_at,
  p.categoria,
  EXISTS (
    SELECT 1
    FROM photo_of_the_day pod
    WHERE pod.photo_id = p.id
      AND pod.selected_date = business_date(p.created_at)
  ) AS is_photo_of_the_day
FROM photos p
WHERE p.is_shared = true;

COMMENT ON VIEW feed_photos IS 'Feed de fotos compartilhadas. is_photo_of_the_day usa data de negócio (America/Sao_Paulo).';
