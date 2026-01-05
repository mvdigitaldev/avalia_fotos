-- Corrigir constraint para permitir photo_id ou comment_id NULL quando conteúdo foi deletado
-- Isso é necessário porque quando o conteúdo é deletado, o ON DELETE SET NULL define esses campos como NULL
-- Mesmo que o status ainda seja 'pending', se o conteúdo foi deletado (NULL), deve ser permitido

-- Remover a constraint antiga
ALTER TABLE reports
DROP CONSTRAINT IF EXISTS reports_photo_or_comment_check;

-- Nova constraint: permite NULL se conteúdo foi deletado, ou valida estrutura normal
ALTER TABLE reports
ADD CONSTRAINT reports_photo_or_comment_check CHECK (
  -- Se ambos são NULL, significa que conteúdo foi deletado - permitir em qualquer status
  (photo_id IS NULL AND comment_id IS NULL) OR
  -- Se status é 'approved', permite qualquer combinação (conteúdo pode ter sido deletado)
  (status = 'approved') OR
  -- Caso contrário, valida estrutura normal
  (report_type = 'photo' AND photo_id IS NOT NULL AND comment_id IS NULL) OR
  (report_type = 'comment' AND comment_id IS NOT NULL AND photo_id IS NULL)
);

