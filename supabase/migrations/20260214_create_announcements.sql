-- Announcements (avisos): feed admin-only publications
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  link TEXT,
  is_pinned BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  author_id UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_announcements_created_at ON announcements(created_at DESC);
CREATE INDEX idx_announcements_is_pinned ON announcements(is_pinned) WHERE is_pinned = TRUE;

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- SELECT: all authenticated users can read
CREATE POLICY "announcements_select_authenticated"
  ON announcements
  FOR SELECT
  TO authenticated
  USING (true);

-- INSERT/UPDATE/DELETE: only admins
CREATE POLICY "announcements_insert_admin"
  ON announcements
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = TRUE)
  );

CREATE POLICY "announcements_update_admin"
  ON announcements
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = TRUE)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = TRUE)
  );

CREATE POLICY "announcements_delete_admin"
  ON announcements
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.is_admin = TRUE)
  );

-- Only one pinned announcement: when setting is_pinned = true, unpin others
CREATE OR REPLACE FUNCTION announcements_unpin_others()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_pinned = TRUE THEN
    UPDATE announcements SET is_pinned = FALSE WHERE id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_announcements_unpin_others
  BEFORE INSERT OR UPDATE OF is_pinned ON announcements
  FOR EACH ROW
  WHEN (NEW.is_pinned = TRUE)
  EXECUTE FUNCTION announcements_unpin_others();

-- User last seen for unread count
CREATE TABLE user_announcement_last_seen (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_announcement_last_seen ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_announcement_last_seen_select_own"
  ON user_announcement_last_seen
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "user_announcement_last_seen_insert_own"
  ON user_announcement_last_seen
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_announcement_last_seen_update_own"
  ON user_announcement_last_seen
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Storage bucket for announcement images (public read; upload via app by authenticated users)
INSERT INTO storage.buckets (id, name, public)
VALUES ('announcements', 'announcements', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "announcements_storage_public_read"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'announcements');

CREATE POLICY "announcements_storage_authenticated_upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'announcements');

CREATE POLICY "announcements_storage_authenticated_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'announcements');
