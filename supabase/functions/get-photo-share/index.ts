import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  // CORS headers para permitir acesso da página web
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  // Tratar preflight OPTIONS
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const photoId = url.searchParams.get('photoId');

    if (!photoId) {
      return new Response(
        JSON.stringify({ error: 'photoId é obrigatório' }),
        { 
          status: 400, 
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json' 
          } 
        }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    if (!supabaseUrl || !supabaseAnonKey) {
      return new Response(
        JSON.stringify({ error: 'Configuração do Supabase não encontrada' }),
        { 
          status: 500, 
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json' 
          } 
        }
      );
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey);

    // Buscar foto pública (is_shared = true)
    const { data: photo, error: photoError } = await supabaseClient
      .from('photos')
      .select(`
        id,
        image_url,
        score,
        created_at,
        users:user_id (
          username,
          avatar_url
        )
      `)
      .eq('id', photoId)
      .eq('is_shared', true)
      .single();

    if (photoError || !photo) {
      return new Response(
        JSON.stringify({ error: 'Foto não encontrada ou não compartilhada' }),
        { 
          status: 404, 
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json' 
          } 
        }
      );
    }

    // Buscar links das lojas
    const { data: storeLinks, error: linksError } = await supabaseClient
      .from('app_store_links')
      .select('platform, store_url');

    // Se houver erro ao buscar links, continuar sem eles (não é crítico)
    const links = {
      ios: storeLinks?.find(l => l.platform === 'ios')?.store_url || '',
      android: storeLinks?.find(l => l.platform === 'android')?.store_url || ''
    };

    return new Response(
      JSON.stringify({ photo, storeLinks: links }),
      { 
        status: 200, 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    );
  } catch (error) {
    console.error('Erro na Edge Function get-photo-share:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Erro interno do servidor' }),
      { 
        status: 500, 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    );
  }
});
