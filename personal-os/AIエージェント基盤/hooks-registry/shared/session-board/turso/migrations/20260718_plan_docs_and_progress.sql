-- 子06 計画ミラー同期（2026-07-18・当日ボードSQL化program）
-- 対象DB: personal-os-inbox（focusmapが読む表示キャッシュ。board DBではない）
-- 適用（人間ゲート）: turso db shell personal-os-inbox < このファイル
-- 正本境界: md(git)が計画の正本。この2表は md→DB 一方向の読み取り専用ミラー。
--           DB側から計画本文を書き換える経路は作らない（INSERT/UPDATE は plansync のみ）。
-- 注意: CREATE TABLE IF NOT EXISTS なので再実行は安全（既存を壊さない）。

-- 計画文書1行 = md 1ファイル（program.md・子計画md・実装/レビュー共通.md・評価md・単発plan.md）
CREATE TABLE IF NOT EXISTS plan_docs (
  path         TEXT PRIMARY KEY,   -- ~/Private repo相対path（冪等キー）
  program_slug TEXT NOT NULL,      -- 所属する active計画フォルダ名（例: 2026-07-17-当日ボードSQL化）
  kind         TEXT NOT NULL,      -- program | single | child | role | eval
  nn           TEXT,               -- 子/評価の2桁連番（無ければ空文字）
  title        TEXT,               -- 先頭H1 or ファイル名
  bucket       TEXT NOT NULL,      -- 現状 'active' 固定（将来の状態拡張余地）
  body         TEXT NOT NULL,      -- 生md本文（表示キャッシュ）
  content_hash TEXT NOT NULL,      -- sha256(body)。同一なら再送スキップ（冪等）
  git_commit   TEXT,               -- そのファイルへの最終コミットhash（鮮度突合用）
  synced_at    TEXT NOT NULL       -- ミラー更新時刻(ISO)
);

CREATE INDEX IF NOT EXISTS idx_plan_docs_slug ON plan_docs (program_slug);
CREATE INDEX IF NOT EXISTS idx_plan_docs_kind ON plan_docs (kind);

-- 計画1つ(program_slug)あたりの進捗集計。_planops_map 算出値のキャッシュ。
CREATE TABLE IF NOT EXISTS plan_progress (
  program_slug TEXT PRIMARY KEY,   -- plan_docs.program_slug に対応
  child_done   INTEGER NOT NULL DEFAULT 0,  -- 子N（状態=完了の子数。単発は0）
  child_total  INTEGER NOT NULL DEFAULT 0,  -- 子M（子計画総数。単発は0）
  cond_done    INTEGER NOT NULL DEFAULT 0,  -- 完了条件x（チェック済み）
  cond_total   INTEGER NOT NULL DEFAULT 0,  -- 完了条件y（総数）
  parse_ok     INTEGER NOT NULL DEFAULT 1,  -- 1=集計成功 / 0=パース失敗（本文閲覧は生きる）
  updated_at   TEXT NOT NULL
);
