-- Migration: Verificar e garantir que os cron jobs de notificação free estão ativos
-- Data: 2026-01-17
-- 
-- Esta migration verifica se os cron jobs existem e os recria se necessário

-- 1. Verificar e remover cron jobs antigos se existirem (para evitar duplicatas)
DO $$
BEGIN
  -- Remover cron jobs antigos se existirem
  PERFORM cron.unschedule('send-free-plan-notification-8am');
  PERFORM cron.unschedule('send-free-plan-notification-7pm');
EXCEPTION
  WHEN OTHERS THEN
    -- Ignorar erro se os jobs não existirem
    NULL;
END $$;

-- 2. Criar/recriar cron job para enviar notificações às 8h BRT (11h UTC)
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

-- 3. Criar/recriar cron job para enviar notificações às 19h BRT (22h UTC)
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

-- 4. Verificar se os cron jobs foram criados com sucesso
-- Esta query pode ser executada manualmente para verificar:
-- SELECT * FROM cron.job WHERE jobname IN ('send-free-plan-notification-8am', 'send-free-plan-notification-7pm');

-- Nota: Os cron jobs estão configurados para o horário do Brasil (UTC-3):
-- - 8h BRT = 11h UTC
-- - 19h BRT = 22h UTC
-- 
-- Para verificar o status dos cron jobs, execute:
-- SELECT jobid, jobname, schedule, active, command 
-- FROM cron.job 
-- WHERE jobname LIKE 'send-free-plan-notification%';
