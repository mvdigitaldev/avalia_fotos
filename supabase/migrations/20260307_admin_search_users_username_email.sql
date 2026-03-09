-- RPC para busca de usuários por username OU email (apenas admins)
-- Mínimo 4 caracteres, LIMIT 30 para performance

CREATE OR REPLACE FUNCTION admin_search_users(p_query text)
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  is_user_admin BOOLEAN;
  search_term text;
BEGIN
  SELECT is_admin INTO is_user_admin FROM users WHERE id = auth.uid();
  IF is_user_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Acesso negado. Apenas administradores podem buscar usuários.';
  END IF;

  search_term := trim(p_query);
  IF length(search_term) < 4 THEN
    RETURN;
  END IF;

  search_term := '%' || search_term || '%';

  RETURN QUERY
  SELECT row_to_json(u)
  FROM users u
  WHERE (u.username IS NOT NULL AND u.username ILIKE search_term)
     OR (u.email IS NOT NULL AND u.email ILIKE search_term)
  ORDER BY u.username NULLS LAST, u.email
  LIMIT 30;
END;
$$;

COMMENT ON FUNCTION admin_search_users(text) IS 'Busca usuários por username ou email. Mínimo 4 caracteres. Apenas admins.';
