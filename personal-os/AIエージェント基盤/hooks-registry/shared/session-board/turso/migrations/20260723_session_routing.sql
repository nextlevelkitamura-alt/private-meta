-- Focusmap Daily: session実行ContextとTheme/Plan分類提案（additive・既存表を変更しない）
-- 対象DB: personal-os-board
-- 適用は人間ゲート: turso db shell personal-os-board < このファイル
-- remote URL・prompt全文・secretは保存しない。event_fingerprintはsession/turn/runtime由来、safe_summaryはマスク済み短文。

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS session_execution_contexts (
  session_key          TEXT PRIMARY KEY,
  runtime              TEXT NOT NULL CHECK (runtime IN ('codex', 'claude')),
  repo_key             TEXT NOT NULL,
  display_name         TEXT NOT NULL,
  scope_kind           TEXT NOT NULL CHECK (scope_kind IN ('git', 'folder')),
  identity_state       TEXT NOT NULL CHECK (identity_state IN ('detected', 'unregistered')),
  canonical_repo_path  TEXT,
  worktree_root        TEXT NOT NULL,
  cwd_path             TEXT NOT NULL,
  branch               TEXT,
  first_seen_at        TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_session_execution_repo
  ON session_execution_contexts(repo_key, updated_at);

CREATE TABLE IF NOT EXISTS session_route_proposals (
  id                  TEXT PRIMARY KEY,
  session_key         TEXT NOT NULL,
  turn_id             TEXT NOT NULL,
  runtime             TEXT NOT NULL CHECK (runtime IN ('codex', 'claude')),
  repo_key            TEXT NOT NULL,
  event_fingerprint   TEXT NOT NULL,
  safe_summary        TEXT,
  route_kind          TEXT NOT NULL DEFAULT 'pending'
    CHECK (route_kind IN ('pending', 'plan', 'theme_work', 'plan_candidate', 'theme_candidate', 'unclassified')),
  theme_id            TEXT,
  plan_slug           TEXT,
  reason              TEXT,
  status              TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'proposed', 'accepted', 'rejected', 'superseded')),
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  UNIQUE(session_key, turn_id)
);

CREATE INDEX IF NOT EXISTS idx_session_route_current
  ON session_route_proposals(session_key, status, updated_at);
CREATE INDEX IF NOT EXISTS idx_session_route_repo
  ON session_route_proposals(repo_key, created_at);
