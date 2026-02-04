import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization header obrigatório' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const { userId, newPassword } = await req.json();

    if (!userId || !newPassword || typeof newPassword !== 'string') {
      return new Response(JSON.stringify({ error: 'userId e newPassword são obrigatórios' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    if (newPassword.length < 6) {
      return new Response(JSON.stringify({ error: 'Senha deve ter pelo menos 6 caracteres' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: userError } = await supabaseAuth.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Usuário não autenticado' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const { data: adminUser, error: adminError } = await supabaseAdmin
      .from('users')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    if (adminError || !adminUser?.is_admin) {
      return new Response(JSON.stringify({ error: 'Acesso negado. Apenas administradores podem alterar senhas.' }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(userId, { password: newPassword });

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ success: true, message: 'Senha atualizada com sucesso' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Erro admin-update-user-password:', error);
    return new Response(JSON.stringify({
      error: error?.message || 'Erro ao atualizar senha'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});
