import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY não configurados');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse webhook body
    const webhookData = await req.json();
    
    console.log('Webhook recebido do Asaas:', JSON.stringify(webhookData, null, 2));

    // Verificar tipo de evento (evento do Asaas)
    const event = webhookData.event;
    const payment = webhookData.payment || webhookData; // Asaas pode enviar payment diretamente ou em payment.payment

    if (!payment || !payment.id) {
      console.warn('Webhook sem dados de pagamento válidos');
      return new Response(JSON.stringify({ message: 'Webhook sem dados válidos' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const paymentId = payment.id;
    const paymentStatus = payment.status;
    const customerId = payment.customer;

    console.log(`Processando evento: ${event}, Payment ID: ${paymentId}, Status: ${paymentStatus}`);

    // Buscar payment_history pelo transaction_id (ID da cobrança do Asaas)
    const { data: paymentHistory, error: historyError } = await supabase
      .from('payment_history')
      .select('*, plans:plan_id(id, duration_months)')
      .eq('transaction_id', paymentId)
      .maybeSingle();

    if (historyError) {
      console.error('Erro ao buscar payment_history:', historyError);
      throw new Error(`Erro ao buscar payment_history: ${historyError.message}`);
    }

    if (!paymentHistory) {
      console.warn(`Payment history não encontrado para transaction_id: ${paymentId}`);
      return new Response(JSON.stringify({ 
        message: 'Payment history não encontrado',
        paymentId 
      }), {
        status: 200, // Retornar 200 para não gerar retry do Asaas
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const userId = paymentHistory.user_id;
    const planId = paymentHistory.plan_id;
    const planData = paymentHistory.plans as any;
    const durationMonths = planData?.duration_months;

    // Processar eventos do pagamento
    if (paymentStatus === 'RECEIVED' || paymentStatus === 'CONFIRMED' || event === 'PAYMENT_RECEIVED') {
      console.log(`Pagamento confirmado para user ${userId}, plan ${planId}`);

      // 1. Atualizar payment_history com status paid
      const paymentDate = payment.paymentDate || payment.confirmedDate || new Date().toISOString();
      
      const { error: updateHistoryError } = await supabase
        .from('payment_history')
        .update({
          payment_status: 'paid',
          payment_date: paymentDate,
          updated_at: new Date().toISOString(),
        })
        .eq('transaction_id', paymentId);

      if (updateHistoryError) {
        console.error('Erro ao atualizar payment_history:', updateHistoryError);
        throw new Error(`Erro ao atualizar payment_history: ${updateHistoryError.message}`);
      }

      // 2. Atualizar user_plans
      // Desativar plano atual (se houver)
      const { error: deactivateError } = await supabase
        .from('user_plans')
        .update({
          is_active: false,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId)
        .eq('is_active', true);

      if (deactivateError) {
        console.error('Erro ao desativar plano atual:', deactivateError);
        // Não interromper o processo se falhar
      }

      // Calcular expires_at baseado em durationMonths
      let expiresAt: string | null = null;
      if (durationMonths) {
        const expiryDate = new Date();
        expiryDate.setMonth(expiryDate.getMonth() + durationMonths);
        expiresAt = expiryDate.toISOString();
      }

      // Criar novo registro com plano ativo
      const { error: createPlanError } = await supabase
        .from('user_plans')
        .insert({
          user_id: userId,
          plan_id: planId,
          is_active: true,
          started_at: new Date().toISOString(),
          expires_at: expiresAt,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });

      if (createPlanError) {
        console.error('Erro ao criar user_plan:', createPlanError);
        throw new Error(`Erro ao criar user_plan: ${createPlanError.message}`);
      }

      console.log(`Plano ${planId} ativado para user ${userId}`);

      return new Response(JSON.stringify({
        message: 'Pagamento processado com sucesso',
        paymentId,
        userId,
        planId
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });

    } else if (paymentStatus === 'OVERDUE' || event === 'PAYMENT_OVERDUE') {
      // Pagamento vencido
      console.log(`Pagamento vencido: ${paymentId}`);
      
      const { error: updateError } = await supabase
        .from('payment_history')
        .update({
          payment_status: 'overdue',
          updated_at: new Date().toISOString(),
        })
        .eq('transaction_id', paymentId);

      if (updateError) {
        console.error('Erro ao atualizar status para overdue:', updateError);
      }

      return new Response(JSON.stringify({
        message: 'Status atualizado para overdue',
        paymentId
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });

    } else if (paymentStatus === 'REFUNDED' || event === 'PAYMENT_REFUNDED') {
      // Pagamento reembolsado
      console.log(`Pagamento reembolsado: ${paymentId}`);
      
      const { error: updateError } = await supabase
        .from('payment_history')
        .update({
          payment_status: 'refunded',
          refunded_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('transaction_id', paymentId);

      if (updateError) {
        console.error('Erro ao atualizar status para refunded:', updateError);
      }

      // Desativar plano se foi reembolsado
      if (paymentHistory.user_id) {
        const { error: deactivateError } = await supabase
          .from('user_plans')
          .update({
            is_active: false,
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', paymentHistory.user_id)
          .eq('plan_id', planId)
          .eq('is_active', true);

        if (deactivateError) {
          console.error('Erro ao desativar plano após reembolso:', deactivateError);
        }
      }

      return new Response(JSON.stringify({
        message: 'Status atualizado para refunded',
        paymentId
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });

    } else {
      // Outros eventos (ignorar ou logar)
      console.log(`Evento não processado: ${event}, Status: ${paymentStatus}`);
      
      return new Response(JSON.stringify({
        message: 'Evento recebido mas não processado',
        event,
        paymentStatus
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    }

  } catch (error) {
    console.error('Erro ao processar webhook do Asaas:', error);
    return new Response(JSON.stringify({
      error: error.message || 'Erro desconhecido'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});

