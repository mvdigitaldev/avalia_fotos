-- Adicionar campo is_admin na tabela users
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE NOT NULL;

-- Criar índice para otimizar consultas de admin
CREATE INDEX IF NOT EXISTS idx_users_is_admin ON users(is_admin) WHERE is_admin = TRUE;

-- Criar tabela reports (denúncias)
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  photo_id UUID REFERENCES photos(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  report_type TEXT NOT NULL CHECK (report_type IN ('photo', 'comment')),
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  CONSTRAINT reports_photo_or_comment_check CHECK (
    (report_type = 'photo' AND photo_id IS NOT NULL AND comment_id IS NULL) OR
    (report_type = 'comment' AND comment_id IS NOT NULL AND photo_id IS NULL)
  )
);

-- Criar índices para otimizar consultas
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_photo_id ON reports(photo_id);
CREATE INDEX IF NOT EXISTS idx_reports_comment_id ON reports(comment_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

-- Criar trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_reports_updated_at
  BEFORE UPDATE ON reports
  FOR EACH ROW
  EXECUTE FUNCTION update_reports_updated_at();

-- RLS Policies para reports

-- Habilitar RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Política: Usuários autenticados podem criar denúncias
CREATE POLICY "Users can create reports"
  ON reports
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Política: Usuários podem ver suas próprias denúncias
CREATE POLICY "Users can view their own reports"
  ON reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Política: Admins podem ver todas as denúncias
CREATE POLICY "Admins can view all reports"
  ON reports
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.is_admin = TRUE
    )
  );

-- Política: Admins podem atualizar denúncias
CREATE POLICY "Admins can update reports"
  ON reports
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.is_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.is_admin = TRUE
    )
  );

-- Função RPC para contar denúncias pendentes (apenas admins)
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
  -- Obter ID do usuário atual
  current_user_id := auth.uid();
  
  -- Verificar se o usuário é admin
  SELECT is_admin INTO is_user_admin
  FROM users
  WHERE id = current_user_id;
  
  -- Se não for admin, retornar erro
  IF is_user_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Acesso negado. Apenas administradores podem acessar esta função.';
  END IF;
  
  -- Contar denúncias pendentes
  SELECT COUNT(*) INTO count_result
  FROM reports
  WHERE status = 'pending';
  
  RETURN count_result;
END;
$$;

-- Comentários para documentação
COMMENT ON TABLE reports IS 'Tabela para armazenar denúncias de posts e comentários';
COMMENT ON COLUMN users.is_admin IS 'Indica se o usuário é administrador do sistema';
COMMENT ON FUNCTION get_pending_reports_count() IS 'Retorna a quantidade de denúncias pendentes. Apenas administradores podem executar.';





