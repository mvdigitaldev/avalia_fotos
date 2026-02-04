-- Migration: Função RPC para obter status de plano pago de múltiplos usuários
-- Retorna user_id e has_paid_plan (true se usuário tem plano ativo com price > 0)

CREATE OR REPLACE FUNCTION get_users_paid_plan_status(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, has_paid_plan boolean)
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
      AND up.user_id = ANY(p_user_ids)
  )
  SELECT u.user_id, (pu.user_id IS NOT NULL)
  FROM unnest(p_user_ids) AS u(user_id)
  LEFT JOIN paid_users pu ON pu.user_id = u.user_id;
END;
$$;
