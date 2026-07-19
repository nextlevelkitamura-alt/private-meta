-- 子08「サブエージェント入れ子可視化」: セッション配下のサブエージェント個体を積む新規テーブル
-- 対象DB: personal-os-board（sessions と同じboard DB・新規テーブルのみ・既存テーブルは変更しない）
-- 適用（人間ゲート）: turso db shell personal-os-board < このファイル
-- 注意: CREATE TABLE/INDEX は IF NOT EXISTS で冪等（再実行しても安全）。
--
-- 設計（子計画08 方針1・4）:
--   SubagentStart/Stop hook が board.py sub-start / sub-end を叩くたびに、ここへ
--   サブ個体の行を積む（開始=running行を1本INSERT・終了=running行を1本close）。
--   体数±1・🔵⇄🟢 の既存機械遷移は sessions/MD 側そのままで、この表は「中身の見える化」を足すだけ。
--   ラベル（何をやっているか1行）の意味づけは board.py sub-label（AI）だけが書く＝hookは文面を創作しない。
--   「稼働中N体」は status='running' の集計でSQL導出する（主観値・第2の状態台帳を保存しない）。
--   session_key は sessions/session_events と同じ `s:xxxx` 形式。cross-DBは張らない参照値。

CREATE TABLE IF NOT EXISTS session_subagents (
  id           TEXT PRIMARY KEY,          -- uuid hex
  session_key  TEXT NOT NULL,             -- 親セッション（s:xxxx・sessions.session_key と同形式）
  sub_seq      INTEGER NOT NULL,          -- 親セッション×日 内の連番（表示順・sub-label の --seq 指定に使う）
  label        TEXT,                      -- 何をやっているか1行（NULL=未設定→UIは「(無題のサブ作業)」表示）
  status       TEXT NOT NULL DEFAULT 'running',  -- running | done
  started_at   TEXT NOT NULL,             -- ISO8601（開始時刻・所要時間の起点）
  ended_at     TEXT,                      -- ISO8601（終了時刻・running中はNULL）
  session_date TEXT NOT NULL              -- YYYY-MM-DD（当日入れ子の絞り込み・連番スコープ）
);

CREATE INDEX IF NOT EXISTS idx_session_subagents_key_date
  ON session_subagents(session_key, session_date);
