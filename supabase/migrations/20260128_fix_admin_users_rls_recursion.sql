-- Corrigir recursão infinita nas políticas RLS da tabela users.
-- O problema: políticas que fazem SELECT em users para checar is_admin
-- disparam novamente as políticas de users, causando loop infinito.
-- Solução: usar função SECURITY DEFINER que bypassa RLS ao consultar users.

-- 1. Criar função que verifica se o usuário atual é admin (bypassa RLS)
CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.users WHERE id = auth.uid() LIMIT 1),
    false
  );
$$;

-- 2. Remover políticas problemáticas da tabela users
DROP POLICY IF EXISTS "admin_select_any_user" ON users;
DROP POLICY IF EXISTS "admin_update_any_user" ON users;

-- 3. Recriar políticas usando a função (sem recursão)
CREATE POLICY "admin_select_any_user"
  ON users
  FOR SELECT
  TO authenticated
  USING (public.is_current_user_admin());

CREATE POLICY "admin_update_any_user"
  ON users
  FOR UPDATE
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- 4. Atualizar políticas em user_plans para usar a função
DROP POLICY IF EXISTS "admin_select_user_plans" ON user_plans;
DROP POLICY IF EXISTS "admin_update_user_plans" ON user_plans;
DROP POLICY IF EXISTS "admin_insert_user_plans" ON user_plans;

CREATE POLICY "admin_select_user_plans"
  ON user_plans
  FOR SELECT
  TO authenticated
  USING (public.is_current_user_admin());

CREATE POLICY "admin_update_user_plans"
  ON user_plans
  FOR UPDATE
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

CREATE POLICY "admin_insert_user_plans"
  ON user_plans
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_current_user_admin());
