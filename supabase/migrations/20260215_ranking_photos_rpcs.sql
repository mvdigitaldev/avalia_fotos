-- RPCs de ranking e fotos do mês com data de negócio (America/Sao_Paulo)
-- Depende de 20260215_business_timezone_helpers.sql

-- get_monthly_ranking: ranking de user_monthly_scores para mês de negócio
CREATE OR REPLACE FUNCTION get_monthly_ranking(
  p_year int,
  p_month int,
  p_limit int DEFAULT 10,
  p_offset int DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  score numeric,
  photos_count int,
  username text,
  avatar_url text,
  position bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  WITH ranked AS (
    SELECT
      ums.user_id,
      ums.score,
      ums.photos_count,
      u.username,
      u.avatar_url,
      ROW_NUMBER() OVER (ORDER BY ums.score DESC) AS rn
    FROM user_monthly_scores ums
    INNER JOIN users u ON u.id = ums.user_id
    WHERE ums.month = p_month AND ums.year = p_year
  )
  SELECT
    ranked.user_id,
    ranked.score,
    ranked.photos_count,
    ranked.username,
    ranked.avatar_url,
    ranked.rn AS position
  FROM ranked
  ORDER BY ranked.rn
  LIMIT p_limit OFFSET p_offset
$$;

-- get_best_photos_of_month: fotos do mês com faixa UTC de negócio
CREATE OR REPLACE FUNCTION get_best_photos_of_month(
  p_year int,
  p_month int,
  p_limit int DEFAULT 10,
  p_offset int DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  SELECT b.start_utc, b.end_utc INTO v_start, v_end
  FROM business_month_bounds_utc(p_year, p_month) b;
  
  RETURN QUERY
  SELECT row_to_json(photo_row)
  FROM (
    SELECT
      ph.*,
      u.username,
      u.avatar_url AS user_avatar_url
    FROM photos ph
    INNER JOIN users u ON u.id = ph.user_id
    WHERE ph.is_shared = true
      AND ph.created_at >= v_start
      AND ph.created_at < v_end
    ORDER BY ph.score DESC
    LIMIT p_limit OFFSET p_offset
  ) photo_row;
END;
$$;

-- count_shared_photos_in_month_br: contagem de fotos compartilhadas no mês de negócio
CREATE OR REPLACE FUNCTION count_shared_photos_in_month_br(p_year int, p_month int)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::int
  FROM photos ph
  CROSS JOIN business_month_bounds_utc(p_year, p_month) b
  WHERE ph.is_shared = true
    AND ph.created_at >= b.start_utc
    AND ph.created_at < b.end_utc
$$;
