-- Migration: Corrigir ambiguidade de coluna user_id na função get_free_plan_users
-- Data: 2026-01-24
--
-- Problema: A coluna user_id estava sendo referenciada de forma ambígua na query
-- Solução: Qualificar todas as referências de colunas com aliases de tabela explícitos

CREATE OR REPLACE FUNCTION get_free_plan_users()
RETURNS TABLE(user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH all_users AS (
    -- Buscar todos os usuários
    SELECT id as user_id
    FROM auth.users
  ),
  users_with_active_plans AS (
    -- Buscar usuários com planos ativos e seus preços
    SELECT 
      up.user_id,
      p.price
    FROM user_plans up
    INNER JOIN plans p ON up.plan_id = p.id
    WHERE up.is_active = true
  ),
  free_users AS (
    -- Identificar usuários free:
    -- 1. Usuários sem plano ativo
    -- 2. Usuários com plano ativo mas price = null
    SELECT au.user_id
    FROM all_users au
    LEFT JOIN users_with_active_plans uwap ON au.user_id = uwap.user_id
    WHERE uwap.user_id IS NULL -- Sem plano ativo (qualificado explicitamente)
       OR uwap.price IS NULL    -- Plano ativo mas grátis
  )
  SELECT fu.user_id FROM free_users fu; -- Qualificar com alias 'fu'
END;
$$;
