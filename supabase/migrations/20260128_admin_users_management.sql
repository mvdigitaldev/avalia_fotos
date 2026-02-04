-- Admin Users Management: políticas RLS e RPC para gerenciamento de usuários por admins

-- 1. Políticas RLS para tabela users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_select_any_user"
  ON users
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  );

CREATE POLICY "admin_update_any_user"
  ON users
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  );

-- 2. Políticas RLS para tabela user_plans
ALTER TABLE user_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_select_user_plans"
  ON user_plans
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  );

CREATE POLICY "admin_update_user_plans"
  ON user_plans
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  );

CREATE POLICY "admin_insert_user_plans"
  ON user_plans
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.is_admin = TRUE
    )
  );

-- 3. RPC para busca de usuário por email (apenas admins)
CREATE OR REPLACE FUNCTION admin_search_user_by_email(p_email text)
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  is_user_admin BOOLEAN;
BEGIN
  SELECT is_admin INTO is_user_admin
  FROM users
  WHERE id = auth.uid();

  IF is_user_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Acesso negado. Apenas administradores podem buscar usuários.';
  END IF;

  IF p_email IS NULL OR trim(p_email) = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT row_to_json(u)
  FROM users u
  WHERE u.email IS NOT NULL
    AND u.email ILIKE '%' || trim(p_email) || '%'
  ORDER BY u.email
  LIMIT 50;
END;
$$;
