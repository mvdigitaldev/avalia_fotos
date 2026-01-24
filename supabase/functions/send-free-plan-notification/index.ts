import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

// Função para gerar JWT assinado para autenticação OAuth2
async function createSignedJwt(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600; // Token válido por 1 hora

  // Header do JWT
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  };

  // Payload do JWT
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: serviceAccount.token_uri,
    iat: now,
    exp: expiry,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  };

  // Codificar header e payload em base64url
  const base64UrlEncode = (str) => {
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));

  // Assinar com a chave privada usando Web Crypto API
  const privateKeyPEM = serviceAccount.private_key;
  
  // Remover headers/footers da chave PEM
  const privateKeyData = privateKeyPEM
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');

  // Converter PEM para formato que o Web Crypto API aceita
  const binaryDer = Uint8Array.from(atob(privateKeyData), c => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`)
  );

  const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));

  return `${encodedHeader}.${encodedPayload}.${encodedSignature}`;
}

// Função para trocar o JWT assinado por um Access Token do Google
async function getAccessToken(serviceAccount) {
  const signedJwt = await createSignedJwt(serviceAccount);
  
  const response = await fetch(serviceAccount.token_uri, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedJwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Erro ao obter access token: ${response.status} ${errorText}`);
  }

  const data = await response.json();
  return data.access_token;
}

// Função para converter todos os valores do objeto data para strings (requisito do FCM)
function convertDataToStrings(data: Record<string, any>): Record<string, string> {
  const converted: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    // Converter para string: null/undefined vira string vazia, boolean vira "true"/"false", etc
    if (value === null || value === undefined) {
      converted[key] = '';
    } else if (typeof value === 'boolean') {
      converted[key] = value ? 'true' : 'false';
    } else if (typeof value === 'number') {
      converted[key] = value.toString();
    } else if (typeof value === 'object') {
      // Se for objeto ou array, converter para JSON string
      converted[key] = JSON.stringify(value);
    } else {
      converted[key] = String(value);
    }
  }
  return converted;
}

// Função para enviar notificação via FCM HTTP v1 API
async function sendFCMNotification(accessToken, projectId, token, title, body, data = {}) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  
  // Converter todos os valores de data para strings (requisito do FCM)
  const dataAsStrings = convertDataToStrings(data);
  
  const message = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: dataAsStrings,
    }
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  });

  if (!response.ok) {
    const errorData = await response.json();
    console.error('Erro FCM:', JSON.stringify(errorData, null, 2));
    throw new Error(`Erro FCM: ${JSON.stringify(errorData, null, 2)}`);
  }

  return await response.json();
}

Deno.serve(async (req) => {
  try {
    console.log('[STEP 0] Iniciando Edge Function send-free-plan-notification');
    
    // Verificar método
    if (req.method !== 'POST') {
      console.error('[ERROR] Método não permitido:', req.method);
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { 
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // STEP 1: Verificar variáveis de ambiente
    console.log('[STEP 1] Verificando variáveis de ambiente...');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    if (!supabaseUrl || supabaseUrl.trim() === '') {
      console.error('[ERROR] SUPABASE_URL não configurado ou vazio');
      throw new Error('SUPABASE_URL não configurado. Configure no Supabase Dashboard > Edge Functions > Secrets');
    }
    console.log(`[INFO] SUPABASE_URL configurado: ${supabaseUrl.substring(0, 30)}...`);

    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseServiceKey || supabaseServiceKey.trim() === '') {
      console.error('[ERROR] SUPABASE_SERVICE_ROLE_KEY não configurado ou vazio');
      throw new Error('SUPABASE_SERVICE_ROLE_KEY não configurado. Configure no Supabase Dashboard > Edge Functions > Secrets');
    }
    console.log(`[INFO] SUPABASE_SERVICE_ROLE_KEY configurado: ${supabaseServiceKey.substring(0, 20)}...`);

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson || serviceAccountJson.trim() === '') {
      console.error('[ERROR] FIREBASE_SERVICE_ACCOUNT_JSON não configurado ou vazio');
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON não configurado. Configure no Supabase Dashboard > Edge Functions > Secrets');
    }
    console.log(`[INFO] FIREBASE_SERVICE_ACCOUNT_JSON configurado: ${serviceAccountJson.length} caracteres`);

    // STEP 2: Parse do Firebase Service Account JSON
    console.log('[STEP 2] Fazendo parse do Firebase Service Account JSON...');
    
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
      
      // Validar campos obrigatórios
      if (!serviceAccount.client_email) {
        throw new Error('Campo client_email não encontrado no Firebase Service Account JSON');
      }
      if (!serviceAccount.private_key) {
        throw new Error('Campo private_key não encontrado no Firebase Service Account JSON');
      }
      if (!serviceAccount.project_id) {
        throw new Error('Campo project_id não encontrado no Firebase Service Account JSON');
      }
      if (!serviceAccount.token_uri) {
        throw new Error('Campo token_uri não encontrado no Firebase Service Account JSON');
      }
      
      console.log(`[INFO] Firebase Service Account válido: project_id=${serviceAccount.project_id}, client_email=${serviceAccount.client_email}`);
    } catch (parseError) {
      console.error('[ERROR] Erro ao fazer parse do FIREBASE_SERVICE_ACCOUNT_JSON:', parseError.message);
      console.error('[ERROR] Stack trace:', parseError.stack);
      throw new Error(`Erro ao processar Firebase Service Account: ${parseError.message}. Verifique se o JSON está válido.`);
    }

    // STEP 3: Inicializar cliente Supabase
    console.log('[STEP 3] Inicializando cliente Supabase...');
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    console.log('[INFO] Cliente Supabase inicializado com sucesso');

    // STEP 4: Buscar usuários free
    console.log('[STEP 4] Buscando usuários com plano free...');
    
    const { data: freeUsers, error: usersError } = await supabase.rpc('get_free_plan_users');

    if (usersError) {
      console.error('[ERROR] Erro ao chamar get_free_plan_users:', {
        message: usersError.message,
        details: usersError.details,
        hint: usersError.hint,
        code: usersError.code
      });
      throw new Error(`Erro ao buscar usuários free: ${usersError.message} (code: ${usersError.code || 'unknown'})`);
    }

    if (!freeUsers || freeUsers.length === 0) {
      console.log('[INFO] Nenhum usuário com plano free encontrado');
      return new Response(JSON.stringify({
        message: 'Nenhum usuário com plano free encontrado',
        sent: 0,
        totalUsers: 0
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    console.log(`[INFO] Encontrados ${freeUsers.length} usuários com plano free`);

    // STEP 5: Processar userIds e buscar tokens
    console.log('[STEP 5] Processando userIds e buscando tokens...');
    
    // Validar formato dos userIds retornados
    const userIds = freeUsers
      .map((u: any) => {
        if (typeof u === 'object' && u !== null && u.user_id) {
          return u.user_id;
        } else if (typeof u === 'string') {
          return u;
        }
        return null;
      })
      .filter((id: any) => id != null && typeof id === 'string');
    
    if (userIds.length === 0 && freeUsers.length > 0) {
      console.warn('[WARN] Formato inesperado dos dados de get_free_plan_users:', JSON.stringify(freeUsers.slice(0, 3)));
      return new Response(JSON.stringify({
        message: 'Formato inesperado dos dados de usuários free',
        sent: 0,
        totalUsers: freeUsers.length,
        validUserIds: 0
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    console.log(`[INFO] ${userIds.length} userIds válidos extraídos de ${freeUsers.length} usuários`);

    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('token, platform, user_id')
      .in('user_id', userIds);

    if (tokensError) {
      console.error('[ERROR] Erro ao buscar tokens:', {
        message: tokensError.message,
        details: tokensError.details,
        hint: tokensError.hint,
        code: tokensError.code
      });
      throw new Error(`Erro ao buscar tokens: ${tokensError.message} (code: ${tokensError.code || 'unknown'})`);
    }

    if (!tokens || tokens.length === 0) {
      console.log('[INFO] Nenhum token encontrado para usuários free');
      return new Response(JSON.stringify({
        message: 'Nenhum token encontrado para usuários free',
        sent: 0,
        totalUsers: freeUsers.length,
        totalTokens: 0
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    console.log(`[INFO] Encontrados ${tokens.length} tokens para enviar notificações`);

    // STEP 6: Gerar access token OAuth2
    console.log('[STEP 6] Gerando access token Firebase OAuth2...');
    
    let accessToken;
    try {
      accessToken = await getAccessToken(serviceAccount);
      console.log('[INFO] Access token Firebase obtido com sucesso');
    } catch (tokenError) {
      console.error('[ERROR] Erro ao obter access token Firebase:', tokenError.message);
      console.error('[ERROR] Stack trace:', tokenError.stack);
      throw new Error(`Erro ao obter access token Firebase: ${tokenError.message}`);
    }

    // STEP 7: Enviar notificações
    console.log('[STEP 7] Enviando notificações...');
    
    // Mensagem da notificação
    const title = 'Desbloqueie recursos exclusivos!';
    const body = 'Assine um plano pago e tenha acesso a recursos premium. Clique para ver os planos disponíveis.';
    const notificationData = {
      type: 'upgrade_plan',
      deep_link: '/plans_assas'
    };

    // Enviar notificação para cada token
    const results = await Promise.allSettled(tokens.map(async (tokenData, index) => {
      try {
        if (!tokenData.token || typeof tokenData.token !== 'string') {
          throw new Error(`Token inválido no índice ${index}`);
        }
        return await sendFCMNotification(
          accessToken, 
          serviceAccount.project_id, 
          tokenData.token, 
          title, 
          body, 
          notificationData
        );
      } catch (tokenError) {
        console.error(`[ERROR] Erro ao enviar notificação para token ${index}:`, tokenError.message);
        throw tokenError;
      }
    }));

    const successful = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.filter(r => r.status === 'rejected').length;

    // Log detalhado de erros para debug
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        const error = result.reason;
        console.error(`[ERROR] Falha ao enviar notificação para token ${index}:`, {
          message: error.message,
          token: tokens[index]?.token?.substring(0, 20) + '...',
          userId: tokens[index]?.user_id
        });
      }
    });

    console.log(`[SUCCESS] Processo concluído: ${successful} sucesso, ${failed} falhas`);

    return new Response(JSON.stringify({
      message: `Notificações enviadas: ${successful} sucesso, ${failed} falhas`,
      successful,
      failed,
      totalUsers: freeUsers.length,
      totalTokens: tokens.length
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('[ERROR] Erro crítico ao enviar notificações para usuários free:', error.message);
    console.error('[ERROR] Stack trace:', error.stack);
    
    return new Response(JSON.stringify({
      error: error.message,
      step: 'Verifique os logs para mais detalhes'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});

