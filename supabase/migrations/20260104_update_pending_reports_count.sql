-- Atualizar função RPC para excluir denúncias com conteúdo deletado da contagem
CREATE OR REPLACE FUNCTION get_pending_reports_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  count_result INTEGER;
  current_user_id UUID;
  is_user_admin BOOLEAN;
BEGIN
  current_user_id := auth.uid();
  
  SELECT is_admin INTO is_user_admin
  FROM users
  WHERE id = current_user_id;
  
  IF is_user_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Acesso negado. Apenas administradores podem acessar esta função.';
  END IF;
  
  -- Contar apenas denúncias pendentes com conteúdo ainda existente
  SELECT COUNT(*) INTO count_result
  FROM reports
  WHERE status = 'pending'
    AND (photo_id IS NOT NULL OR comment_id IS NOT NULL);
  
  RETURN count_result;
END;
$$;

