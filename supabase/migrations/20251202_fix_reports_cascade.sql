-- Alterar foreign key de photo_id de CASCADE para SET NULL
-- Isso permite que as denúncias permaneçam mesmo após a exclusão do conteúdo
ALTER TABLE reports
DROP CONSTRAINT IF EXISTS reports_photo_id_fkey;

ALTER TABLE reports
ADD CONSTRAINT reports_photo_id_fkey
FOREIGN KEY (photo_id)
REFERENCES photos(id)
ON DELETE SET NULL;

-- Alterar foreign key de comment_id de CASCADE para SET NULL
-- Isso permite que as denúncias permaneçam mesmo após a exclusão do conteúdo
ALTER TABLE reports
DROP CONSTRAINT IF EXISTS reports_comment_id_fkey;

ALTER TABLE reports
ADD CONSTRAINT reports_comment_id_fkey
FOREIGN KEY (comment_id)
REFERENCES comments(id)
ON DELETE SET NULL;





