# Configuração de Push Notifications

## Configurações Necessárias

### 1. Firebase Cloud Messaging (FCM)

#### Android
1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Crie um projeto ou selecione um existente
3. Adicione um app Android com o package name: `com.mycompany.avaliafotos`
4. Baixe o arquivo `google-services.json`
5. Coloque o arquivo em `android/app/google-services.json`

#### iOS
1. No Firebase Console, adicione um app iOS com o Bundle ID do seu app
2. Baixe o arquivo `GoogleService-Info.plist`
3. Adicione o arquivo ao projeto Xcode em `ios/Runner/GoogleService-Info.plist`
4. Configure o Push Notifications capability no Xcode

### 2. Configurar Firebase Service Account na Edge Function

A Edge Function `send-push-notification` usa a Service Account do Firebase (método mais seguro):

1. No Firebase Console, vá em **Project Settings** > **Service Accounts**
2. Clique em **Generate New Private Key** para baixar o arquivo JSON da Service Account
3. Abra o arquivo JSON baixado (ex: `avaliafotos-cbfe8-firebase-adminsdk-fbsvc-5896faaf88.json`)
4. No Supabase Dashboard, vá em **Edge Functions** > **send-push-notification** > **Settings** > **Secrets**
5. Adicione a variável de ambiente:
   - Nome: `FIREBASE_SERVICE_ACCOUNT_JSON`
   - Valor: Cole o conteúdo completo do arquivo JSON **como uma string JSON válida**
   
   **Formato do valor**: O JSON deve ser colado minificado (sem quebras de linha) ou como string JSON escapada. Exemplo:
   ```json
   {"type":"service_account","project_id":"avaliafotos-cbfe8","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"...","universe_domain":"googleapis.com"}
   ```
   
   **Dica**: Você pode usar um minificador JSON online ou simplesmente copiar o conteúdo do arquivo e colar diretamente (o Supabase aceita JSON multilinha).

### 3. Configurar Service Role Key na Edge Function

A Edge Function também precisa da Service Role Key do Supabase:

1. No Supabase Dashboard, vá em **Settings** > **API**
2. Copie a **service_role** key (mantenha segredo!)
3. Na Edge Function, adicione a variável de ambiente:
   - Nome: `SUPABASE_SERVICE_ROLE_KEY`
   - Valor: Cole a service_role key

### 4. Configurar URL do Supabase (Opcional)

Se necessário, configure também:
- Nome: `SUPABASE_URL`
- Valor: `https://yulxxamlfxujclnzzcjb.supabase.co`

## Como Funciona

### Fluxo de Notificações

1. **Curtida em Foto**: Quando alguém curte uma foto (que não seja o próprio dono), um trigger no banco detecta e chama a Edge Function para enviar notificação ao dono da foto.

2. **Comentário em Foto**: Quando alguém comenta em uma foto (que não seja o próprio dono), um trigger detecta e envia notificação.

3. **Finalização de Avaliação**: Quando uma foto é avaliada, um trigger detecta e envia notificação. O app verifica se o usuário está na tela de avaliação antes de mostrar a notificação.

4. **Atualização de Plano**: Quando o plano do usuário é atualizado na tabela `user_plans`, um trigger detecta e envia notificação.

### Tabela device_tokens

Os tokens FCM dos dispositivos são armazenados na tabela `device_tokens`:
- Um usuário pode ter múltiplos tokens (múltiplos dispositivos)
- Tokens são atualizados automaticamente quando mudam
- Tokens são removidos quando o usuário faz logout

## Testando

Para testar as notificações:

1. Faça login no app em um dispositivo
2. Em outro dispositivo/usuário, curta ou comente uma foto do primeiro usuário
3. O primeiro usuário deve receber uma notificação push

## Troubleshooting

### Notificações não estão sendo enviadas

1. Verifique se o `FIREBASE_SERVICE_ACCOUNT_JSON` está configurado corretamente na Edge Function (deve ser o JSON completo)
2. Verifique se o JSON da Service Account está válido e completo
3. Verifique se os tokens estão sendo salvos na tabela `device_tokens`
4. Verifique os logs da Edge Function no Supabase Dashboard para erros específicos
5. Verifique se as permissões de notificação foram concedidas no dispositivo
6. Certifique-se de que a Service Account tem as permissões necessárias no Firebase Console

### Token não está sendo salvo

1. **Verifique se o Firebase está inicializado corretamente**:
   - Os arquivos `google-services.json` (Android) e `GoogleService-Info.plist` (iOS) devem estar nos lugares corretos
   - Verifique os logs do app ao iniciar - deve aparecer "Firebase inicializado com sucesso"
   - Se houver erro, verifique se os arquivos estão corretos e se o projeto Firebase está configurado

2. **Verifique se o usuário está autenticado**:
   - O token só é salvo após o login
   - Verifique se há um usuário logado no app
   - O token será salvo automaticamente após o login

3. **Verifique os logs do app**:
   - Procure por mensagens do `NotificationService` nos logs
   - Mensagens esperadas:
     - "Iniciando NotificationService..."
     - "Firebase inicializado com sucesso"
     - "Token FCM obtido: ..."
     - "Token salvo no Supabase para usuário ..."

4. **Verifique permissões**:
   - No Android 13+, o app deve solicitar permissão de notificações
   - No iOS, o app deve solicitar permissão de notificações
   - Se não aparecer o pedido de permissão, verifique se o Firebase está inicializado corretamente

### Edge Function não está sendo chamada (triggers não funcionam)

1. **Verifique se os triggers existem**:
   ```sql
   SELECT trigger_name, event_object_table 
   FROM information_schema.triggers 
   WHERE trigger_name LIKE 'trigger_notify%';
   ```

2. **Verifique se a função `call_send_push_notification` existe**:
   ```sql
   SELECT proname FROM pg_proc WHERE proname = 'call_send_push_notification';
   ```

3. **Teste manualmente a Edge Function**:
   - No Supabase Dashboard, vá em Edge Functions > send-push-notification
   - Use o "Invoke function" para testar com:
     ```json
     {
       "userId": "seu-user-id-aqui",
       "title": "Teste",
       "body": "Esta é uma notificação de teste"
     }
     ```

4. **Verifique os logs da Edge Function**:
   - No Supabase Dashboard, vá em Edge Functions > send-push-notification > Logs
   - Procure por erros 401 (autenticação) ou 500 (erro interno)

5. **Verifique se a Service Role Key está configurada**:
   - A função `call_send_push_notification` precisa da service_role_key para autenticar
   - Verifique se está configurada corretamente na função

### Checklist de Verificação

Use este checklist para garantir que tudo está configurado:

- [ ] Arquivo `google-services.json` está em `android/app/google-services.json`
- [ ] Arquivo `GoogleService-Info.plist` está em `ios/Runner/GoogleService-Info.plist`
- [ ] Firebase está inicializado no app (verifique logs)
- [ ] Permissões de notificação foram concedidas no dispositivo
- [ ] Usuário está autenticado no app
- [ ] Token FCM está sendo salvo na tabela `device_tokens` (verifique no Supabase)
- [ ] `FIREBASE_SERVICE_ACCOUNT_JSON` está configurado na Edge Function
- [ ] `SUPABASE_SERVICE_ROLE_KEY` está configurado na Edge Function
- [ ] Triggers estão criados no banco de dados
- [ ] Edge Function está deployada e ativa

