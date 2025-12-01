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

// Função para enviar notificação via FCM HTTP v1 API
async function sendFCMNotification(accessToken, projectId, token, title, body, data = {}) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  
  const message = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data,
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
    // Verificar método
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Obter dados do corpo da requisição
    const { userId, title, body, data } = await req.json();

    if (!userId || !title || !body) {
      return new Response(JSON.stringify({ error: 'Faltando parâmetros obrigatórios' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Obter credenciais do Firebase
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON não configurado');
    }

    const serviceAccount = JSON.parse(serviceAccountJson);

    // Inicializar Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Buscar tokens do usuário
    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('token, platform')
      .eq('user_id', userId);

    if (tokensError) {
      throw new Error(`Erro ao buscar tokens: ${tokensError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      console.log(`Nenhum token encontrado para o usuário ${userId}`);
      return new Response(JSON.stringify({
        message: 'Nenhum token encontrado para o usuário',
        userId: userId
      }), {
        status: 200, // Retorna 200 mas avisa que não enviou
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // Gerar access token OAuth2 (CORREÇÃO AQUI: Troca o JWT pelo Access Token)
    const accessToken = await getAccessToken(serviceAccount);

    // Enviar notificação para cada token
    const results = await Promise.allSettled(tokens.map(async (tokenData) => {
      return await sendFCMNotification(
        accessToken, 
        serviceAccount.project_id, 
        tokenData.token, 
        title, 
        body, 
        data
      );
    }));

    const successful = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.filter(r => r.status === 'rejected').length;

    return new Response(JSON.stringify({
      message: `Notificações enviadas: ${successful} sucesso, ${failed} falhas`,
      successful,
      failed
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('Erro ao enviar notificação:', error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});
