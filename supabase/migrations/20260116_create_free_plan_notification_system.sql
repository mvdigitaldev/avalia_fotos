-- Migration: Sistema de notificações agendadas para usuários com plano free
-- Data: 2026-01-16

-- 1. Criar função RPC para buscar usuários com plano free
-- Um usuário é considerado free se:
-- - Não tem plano ativo, OU
-- - Tem plano ativo mas o plano tem price = null (grátis)
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
    WHERE uwap.user_id IS NULL -- Sem plano ativo
       OR uwap.price IS NULL    -- Plano ativo mas grátis
  )
  SELECT user_id FROM free_users;
END;
$$;

-- 2. Criar schema util se não existir
CREATE SCHEMA IF NOT EXISTS util;

-- 3. Criar função auxiliar para obter project URL do vault
-- (Reutilizar se já existir, caso contrário criar)
CREATE OR REPLACE FUNCTION util.project_url()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  secret_value text;
BEGIN
  -- Tentar recuperar do vault
  SELECT decrypted_secret INTO secret_value 
  FROM vault.decrypted_secrets 
  WHERE name = 'project_url';
  
  -- Se não encontrar, retornar null (será tratado no cron job)
  RETURN secret_value;
END;
$$;

-- 4. Criar função para invocar Edge Function
CREATE OR REPLACE FUNCTION util.invoke_edge_function(
  name text,
  body jsonb,
  timeout_milliseconds int = 5 * 60 * 1000  -- default 5 minute timeout
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_url_value text;
  service_role_key text;
  headers_raw text;
  auth_header text;
BEGIN
  -- Obter project URL
  project_url_value := util.project_url();
  
  IF project_url_value IS NULL THEN
    RAISE EXCEPTION 'project_url não configurado no vault';
  END IF;

  -- Obter service role key do vault
  SELECT decrypted_secret INTO service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';
  
  IF service_role_key IS NULL THEN
    -- Tentar obter do SUPABASE_SERVICE_ROLE_KEY (variável de ambiente do Supabase)
    -- Se não estiver disponível, usar uma chave padrão ou lançar erro
    RAISE EXCEPTION 'service_role_key não configurado no vault';
  END IF;

  -- Se estivermos em uma sessão PostgREST, reutilizar headers de autorização
  headers_raw := current_setting('request.headers', true);

  -- Tentar obter header de autorização se disponível
  auth_header := CASE
    WHEN headers_raw IS NOT NULL THEN
      (headers_raw::json->>'authorization')
    ELSE
      'Bearer ' || service_role_key
  END;

  -- Realizar requisição HTTP assíncrona para a Edge Function
  PERFORM net.http_post(
    url => project_url_value || '/functions/v1/' || name,
    headers => jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', auth_header
    ),
    body => body,
    timeout_milliseconds => timeout_milliseconds
  );
END;
$$;

-- 5. Criar cron job para enviar notificações às 8h BRT (11h UTC)
SELECT cron.schedule(
  'send-free-plan-notification-8am',
  '0 11 * * *', -- Executa diariamente às 8h BRT (11h UTC)
  $$
  SELECT util.invoke_edge_function(
    'send-free-plan-notification',
    '{}'::jsonb
  );
  $$
);

-- 6. Criar cron job para enviar notificações às 19h BRT (22h UTC)
SELECT cron.schedule(
  'send-free-plan-notification-7pm',
  '0 22 * * *', -- Executa diariamente às 19h BRT (22h UTC)
  $$
  SELECT util.invoke_edge_function(
    'send-free-plan-notification',
    '{}'::jsonb
  );
  $$
);

-- Nota: Os cron jobs estão configurados para o horário do Brasil (UTC-3):
-- - 8h BRT = 11h UTC
-- - 19h BRT = 22h UTC

