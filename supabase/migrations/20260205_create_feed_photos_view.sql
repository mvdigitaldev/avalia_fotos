-- View para o feed com colunas mínimas e is_photo_of_the_day (zero request extra por item).
-- Regra do badge: "foto do dia" = foto selecionada como foto do dia na data da própria foto (created_at::date).
-- Assim a query do feed já traz o boolean e evita N chamadas a isPhotoOfTheDay/get_photo_of_the_day.

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
      AND pod.selected_date = (p.created_at AT TIME ZONE 'UTC')::date
  ) AS is_photo_of_the_day
FROM photos p
WHERE p.is_shared = true;

-- RLS: a view usa as políticas da tabela subjacente (photos).
-- Garantir que SELECT na view seja permitido para usuários autenticados que podem ver fotos compartilhadas.
COMMENT ON VIEW feed_photos IS 'Feed de fotos compartilhadas com colunas mínimas e is_photo_of_the_day (data da foto = selected_date).';
