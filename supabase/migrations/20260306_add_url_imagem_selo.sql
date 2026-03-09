-- Adiciona coluna url_imagem_selo na tabela photo_of_the_day
-- URL da imagem com selo de foto do dia para download

ALTER TABLE photo_of_the_day
ADD COLUMN IF NOT EXISTS url_imagem_selo TEXT;

COMMENT ON COLUMN photo_of_the_day.url_imagem_selo IS 'URL da imagem com selo de foto do dia para download pelos usuários';
