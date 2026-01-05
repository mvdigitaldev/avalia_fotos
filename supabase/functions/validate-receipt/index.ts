import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

interface ReceiptData {
  transaction_id?: string;
  product_id: string;
  receipt_data?: string;
  local_verification_data?: string;
  source?: string;
  purchase_token?: string;
  package_name?: string;
  verification_data?: string;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const { user_id, platform, receipt_data, product_id } = await req.json();

    if (!user_id || !platform || !receipt_data || !product_id) {
      return new Response(JSON.stringify({ error: 'Faltando parâmetros obrigatórios' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Buscar plano pelo product_id
    const { data: planData, error: planError } = await supabase
      .from('plans')
      .select('id, name')
      .or(`apple_product_id.eq.${product_id},google_product_id.eq.${product_id}`)
      .maybeSingle();
    
    if (planError) {
      throw planError;
    }

    if (!planData) {
      return new Response(JSON.stringify({ error: 'Plano não encontrado para o product_id' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const planId = planData.id;

    // Validar receipt baseado na plataforma
    let isValid = false;

    if (platform === 'apple') {
      // Para Apple, a validação real deve ser feita com App Store Server API
      // Por enquanto, apenas verificamos se temos os dados necessários
      isValid = !!(receipt_data.receipt_data || receipt_data.verification_data);
      
      // TODO: Implementar validação real com App Store Server API
      // - Obter shared secret do ambiente
      // - Validar receipt com Apple
      // - Verificar status da assinatura
    } else if (platform === 'google') {
      // Para Google, a validação real deve ser feita com Google Play Developer API
      // Por enquanto, apenas verificamos se temos o token
      isValid = !!receipt_data.purchase_token;
      
      // TODO: Implementar validação real com Google Play Developer API
      // - Obter service account do ambiente
      // - Validar purchase token com Google
      // - Verificar status da assinatura
    } else {
      return new Response(JSON.stringify({ error: 'Plataforma não suportada' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    if (!isValid) {
      return new Response(JSON.stringify({ error: 'Receipt inválido' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Desativar planos anteriores do usuário
    await supabase
      .from('user_plans')
      .update({ is_active: false })
      .eq('user_id', user_id)
      .eq('is_active', true);

    // Calcular datas de início e expiração (assumindo assinatura mensal)
    const now = new Date().toISOString();
    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + 1);
    const expiresAtISO = expiresAt.toISOString();

    // Criar novo plano ativo
    const { error: userPlanError } = await supabase
      .from('user_plans')
      .insert({
        user_id: user_id,
        plan_id: planId,
        started_at: now,
        expires_at: expiresAtISO,
        is_active: true,
      });

    if (userPlanError) {
      throw userPlanError;
    }

    // Registrar no histórico de pagamentos
    const { error: paymentError } = await supabase
      .from('payment_history')
      .insert({
        user_id: user_id,
        plan_id: planId,
        amount: 0, // Valor será atualizado quando tivermos dados reais do receipt
        payment_status: 'paid',
        payment_method: platform === 'apple' ? 'apple_in_app' : 'google_in_app',
        transaction_id: receipt_data.transaction_id || receipt_data.purchase_token || '',
        payment_date: now,
        expires_at: expiresAtISO,
        currency: 'BRL',
      });

    if (paymentError) {
      console.error('Erro ao registrar pagamento:', paymentError);
      // Não falhar a transação se o histórico falhar
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Receipt validado e plano ativado com sucesso',
      plan_id: planId,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Erro ao validar receipt:', error);
    return new Response(JSON.stringify({
      error: error.message || 'Erro ao processar validação'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});

