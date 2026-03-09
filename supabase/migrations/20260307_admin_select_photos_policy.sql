-- Permitir que admins listem (SELECT) qualquer foto para gerenciamento
-- Necessário para a página "Gerenciar fotos do usuário"

CREATE POLICY "Admins can select any photo"
  ON photos
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.is_admin = TRUE
    )
  );
