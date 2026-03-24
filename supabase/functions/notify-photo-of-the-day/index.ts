import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const DEFAULT_N8N_WEBHOOK =
  "https://webhook.iaagents.online/webhook/avalia-instagram-post";

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: photo, error: photoError } = await supabase
      .from("photos")
      .select(`
        *,
        users (
          id,
          username,
          email,
          avatar_url,
          city,
          state
        )
      `)
      .eq("id", record.photo_id)
      .single();

    if (photoError || !photo) {
      console.error("Erro ao buscar foto:", photoError);
      return new Response(JSON.stringify({ error: "Foto não encontrada" }), {
        status: 404,
      });
    }

    const { data: selectedByUser } = await supabase
      .from("users")
      .select("id, username, email, avatar_url")
      .eq("id", record.selected_by)
      .single();

    const webhookUrl =
      Deno.env.get("INSTAGRAM_WEBHOOK_URL") ?? DEFAULT_N8N_WEBHOOK;

    const webhookPayload = {
      tipo: "photo_of_day",
      photo_of_the_day: {
        id: record.id,
        selected_date: record.selected_date,
        created_at: record.created_at,
      },
      photo: {
        id: photo.id,
        image_url: photo.image_url,
        thumbnail_url: photo.thumbnail_url,
        score: photo.score,
        positive_points: photo.positive_points,
        improvement_points: photo.improvement_points,
        is_shared: photo.is_shared,
        likes_count: photo.likes_count,
        comments_count: photo.comments_count,
        observacao: photo.observacao,
        categoria: photo.categoria,
        recado: photo.recado,
        created_at: photo.created_at,
      },
      photo_owner: {
        id: photo.users?.id,
        username: photo.users?.username,
        email: photo.users?.email,
        avatar_url: photo.users?.avatar_url,
        city: photo.users?.city,
        state: photo.users?.state,
      },
      selected_by: {
        id: selectedByUser?.id,
        username: selectedByUser?.username,
        email: selectedByUser?.email,
      },
    };

    const n8nResponse = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(webhookPayload),
    });

    const n8nResult = await n8nResponse.text();
    console.log("n8n respondeu:", n8nResult);

    return new Response(JSON.stringify({ success: true, n8n: n8nResult }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Erro na edge function:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});
