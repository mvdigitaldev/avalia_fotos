-- Função RPC para aprovar denúncia e deletar conteúdo de forma transacional
CREATE OR REPLACE FUNCTION approve_report_and_delete_content(p_report_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_is_admin BOOLEAN;
  v_report_type TEXT;
  v_photo_id UUID;
  v_comment_id UUID;
BEGIN
  -- Verificar se usuário está autenticado
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Verificar se é admin
  SELECT is_admin INTO v_is_admin
  FROM users
  WHERE id = v_user_id;
  
  IF v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Apenas administradores podem aprovar denúncias';
  END IF;

  -- Buscar dados da denúncia
  SELECT report_type, photo_id, comment_id
  INTO v_report_type, v_photo_id, v_comment_id
  FROM reports
  WHERE id = p_report_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Denúncia não encontrada';
  END IF;

  -- Atualizar status para 'approved' PRIMEIRO (permite NULL em photo_id/comment_id)
  UPDATE reports
  SET 
    status = 'approved',
    reviewed_by = v_user_id,
    reviewed_at = NOW()
  WHERE id = p_report_id;

  -- Deletar o conteúdo denunciado
  IF v_report_type = 'photo' AND v_photo_id IS NOT NULL THEN
    DELETE FROM photos WHERE id = v_photo_id;
  ELSIF v_report_type = 'comment' AND v_comment_id IS NOT NULL THEN
    DELETE FROM comments WHERE id = v_comment_id;
  END IF;
END;
$$;

