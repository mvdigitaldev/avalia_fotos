-- Migration: Criar função RPC para toggle de like otimizada
-- Data: 2026-01-24
--
-- Esta função reduz de 3 queries para 1, melhorando performance
-- Verifica se existe like, adiciona/remove e atualiza contador em uma única operação

CREATE OR REPLACE FUNCTION toggle_photo_like(
  p_photo_id UUID,
  p_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_like_id UUID;
  v_new_likes_count INT;
  v_was_liked BOOLEAN;
BEGIN
  -- Verificar se já existe like
  SELECT id INTO v_existing_like_id
  FROM likes
  WHERE photo_id = p_photo_id AND user_id = p_user_id
  LIMIT 1;
  
  IF v_existing_like_id IS NOT NULL THEN
    -- Remover like
    DELETE FROM likes WHERE id = v_existing_like_id;
    
    -- Decrementar contador (garantir que não fique negativo)
    UPDATE photos 
    SET likes_count = GREATEST(0, likes_count - 1),
        updated_at = NOW()
    WHERE id = p_photo_id
    RETURNING likes_count INTO v_new_likes_count;
    
    v_was_liked := false;
  ELSE
    -- Adicionar like
    BEGIN
      INSERT INTO likes (photo_id, user_id, created_at, updated_at)
      VALUES (p_photo_id, p_user_id, NOW(), NOW());
      
      -- Incrementar contador
      UPDATE photos 
      SET likes_count = likes_count + 1,
          updated_at = NOW()
      WHERE id = p_photo_id
      RETURNING likes_count INTO v_new_likes_count;
      
      v_was_liked := true;
    EXCEPTION
      WHEN unique_violation THEN
        -- Se já existe like (race condition), buscar contador atual
        SELECT likes_count INTO v_new_likes_count
        FROM photos
        WHERE id = p_photo_id;
        
        v_was_liked := true; -- Já estava curtido
    END;
  END IF;
  
  -- Retornar resultado
  RETURN json_build_object(
    'liked', v_was_liked,
    'likes_count', COALESCE(v_new_likes_count, 0)
  );
END;
$$;

-- Comentário explicativo
COMMENT ON FUNCTION toggle_photo_like IS 'Função otimizada para toggle de like. Reduz de 3 queries para 1, melhorando performance. Retorna JSON com estado do like e contador atualizado.';
