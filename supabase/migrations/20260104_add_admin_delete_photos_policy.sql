-- Permitir que admins deletem qualquer foto
CREATE POLICY "Admins can delete any photo"
  ON photos
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.is_admin = TRUE
    )
  );


