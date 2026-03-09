-- Refatorar get_candidate_photos_for_day: usar business_day_bounds_utc (faixa UTC para índice)
-- Depende de 20260215_business_timezone_helpers.sql

CREATE OR REPLACE FUNCTION get_candidate_photos_for_day(p_date date)
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH paid_users AS (
    SELECT DISTINCT up.user_id
    FROM user_plans up
    INNER JOIN plans p ON up.plan_id = p.id
    WHERE up.is_active = true
      AND (up.expires_at IS NULL OR up.expires_at >= NOW())
      AND p.price IS NOT NULL
      AND (p.price::numeric) > 0
  ),
  day_bounds AS (
    SELECT start_utc, end_utc FROM business_day_bounds_utc(p_date)
  )
  SELECT row_to_json(photo_row)
  FROM (
    SELECT
      ph.*,
      u.username,
      u.avatar_url AS user_avatar_url
    FROM photos ph
    INNER JOIN paid_users pu ON ph.user_id = pu.user_id
    INNER JOIN users u ON ph.user_id = u.id
    CROSS JOIN day_bounds db
    WHERE ph.is_shared = true
      AND ph.created_at >= db.start_utc
      AND ph.created_at < db.end_utc
    ORDER BY ph.score DESC
  ) photo_row;
END;
$$;
