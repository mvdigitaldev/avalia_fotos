-- Backfill idempotente: copia fotos existentes para auditoria (pula as que já têm photo_id).

INSERT INTO public.photo_evaluation_audit (
  photo_id,
  user_id,
  evaluated_at,
  business_month,
  business_year,
  score,
  image_url,
  thumbnail_url,
  positive_points,
  improvement_points,
  observacao,
  categoria,
  recado,
  is_shared,
  created_at
)
SELECT
  p.id,
  p.user_id,
  COALESCE(p.created_at, now()),
  EXTRACT(MONTH FROM public.business_date(COALESCE(p.created_at, now())))::int,
  EXTRACT(YEAR FROM public.business_date(COALESCE(p.created_at, now())))::int,
  p.score,
  p.image_url,
  p.thumbnail_url,
  p.positive_points,
  p.improvement_points,
  p.observacao,
  p.categoria,
  p.recado,
  COALESCE(p.is_shared, false),
  COALESCE(p.created_at, now())
FROM public.photos p
WHERE NOT EXISTS (
  SELECT 1 FROM public.photo_evaluation_audit a WHERE a.photo_id = p.id
);
