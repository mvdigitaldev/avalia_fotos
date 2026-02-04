-- Migration: Função RPC para buscar fotos candidatas à foto do dia
-- Fotos compartilhadas de usuários com plano pago, na data informada (timezone São Paulo)

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
    WHERE ph.is_shared = true
      AND (ph.created_at AT TIME ZONE 'America/Sao_Paulo')::date = p_date
    ORDER BY ph.score DESC
  ) photo_row;
END;
$$;
