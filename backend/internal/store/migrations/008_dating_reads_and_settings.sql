CREATE TABLE IF NOT EXISTS mobile_message_reads (
  match_id INTEGER NOT NULL REFERENCES mobile_matches(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES mobile_users(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(match_id, user_id)
);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO app_settings(key, value) VALUES
  ('dating.photo_review_enabled', 'true')
ON CONFLICT (key) DO NOTHING;
