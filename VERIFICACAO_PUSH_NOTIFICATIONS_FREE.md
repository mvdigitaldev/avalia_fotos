# Verificação do Sistema de Push Notifications para Usuários Free

## Status da Implementação

✅ **Deep link corrigido**: `/plans_assas` (anteriormente `/plans`)
✅ **Cron jobs configurados**: 2x por dia (8h e 19h BRT)
✅ **Edge Function**: `send-free-plan-notification` implementada
✅ **Função RPC**: `get_free_plan_users()` criada

## Como Verificar os Cron Jobs

### 1. Verificar Status dos Cron Jobs no Supabase

Execute no SQL Editor do Supabase:

```sql
SELECT 
  jobid, 
  jobname, 
  schedule, 
  active, 
  command 
FROM cron.job 
WHERE jobname LIKE 'send-free-plan-notification%';
```

**Resultado esperado:**
- `send-free-plan-notification-8am`: schedule `0 11 * * *` (8h BRT / 11h UTC)
- `send-free-plan-notification-7pm`: schedule `0 22 * * *` (19h BRT / 22h UTC)
- Ambos com `active = true`

### 2. Testar a Função RPC `get_free_plan_users()`

Execute no SQL Editor:

```sql
SELECT * FROM get_free_plan_users();
```

**Resultado esperado:** Lista de `user_id` de usuários com plano free.

### 3. Verificar Tokens de Dispositivos

Execute para ver quantos tokens existem para usuários free:

```sql
SELECT COUNT(*) 
FROM device_tokens dt
WHERE dt.user_id IN (SELECT user_id FROM get_free_plan_users());
```

### 4. Testar Edge Function Manualmente

No Supabase Dashboard:
1. Vá para **Edge Functions** > `send-free-plan-notification`
2. Clique em **Invoke**
3. Envie um POST request vazio: `{}`
4. Verifique os logs para ver se:
   - Usuários free foram encontrados
   - Tokens foram encontrados
   - Notificações foram enviadas com sucesso

### 5. Verificar Configurações do Vault

Certifique-se de que as seguintes secrets estão configuradas no Supabase Vault:

- `project_url` - URL do projeto Supabase (ex: `https://xxxxx.supabase.co`)
- `service_role_key` - Service Role Key do Supabase
- `FIREBASE_SERVICE_ACCOUNT_JSON` - JSON completo da service account do Firebase

**Como verificar:**
1. Vá para **Project Settings** > **Vault**
2. Verifique se as secrets acima existem

## Estrutura do Sistema

```
Cron Job (8h/19h BRT)
  ↓
util.invoke_edge_function()
  ↓
Edge Function: send-free-plan-notification
  ↓
get_free_plan_users() → Lista de user_id free
  ↓
device_tokens WHERE user_id IN (...) → Tokens FCM
  ↓
Firebase FCM API → Envia notificações
  ↓
Usuário recebe notificação com deep link: /plans_assas
```

## Mensagens das Notificações

- **Título**: "Desbloqueie recursos exclusivos!"
- **Corpo**: "Assine um plano pago e tenha acesso a recursos premium. Clique para ver os planos disponíveis."
- **Deep Link**: `/plans_assas`
- **Tipo**: `upgrade_plan`

## Troubleshooting

### Cron Jobs não estão executando

1. Verifique se `pg_cron` está habilitado no Supabase
2. Execute a migration `20260117_verify_free_plan_notification_cron_jobs.sql` para recriar os jobs
3. Verifique os logs do Supabase para erros

### Notificações não estão sendo enviadas

1. Verifique se há usuários free: `SELECT * FROM get_free_plan_users();`
2. Verifique se há tokens: `SELECT COUNT(*) FROM device_tokens;`
3. Verifique os logs da Edge Function no Supabase Dashboard
4. Verifique se `FIREBASE_SERVICE_ACCOUNT_JSON` está configurado corretamente

### Deep link não funciona

1. Verifique se a rota `/plans_assas` está definida em `lib/flutter_flow/nav/nav.dart`
2. Verifique se o `NotificationService` está processando o tipo `upgrade_plan` corretamente
3. Teste o deep link manualmente no app

## Próximos Passos

1. Execute a migration `20260117_verify_free_plan_notification_cron_jobs.sql` no Supabase
2. Verifique os cron jobs usando a query SQL acima
3. Teste a Edge Function manualmente
4. Monitore os logs nas próximas execuções (8h e 19h BRT)
