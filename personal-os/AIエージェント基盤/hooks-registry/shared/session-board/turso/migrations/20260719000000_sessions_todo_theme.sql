-- 子09「大課題テーマ階層と横断表示」: sessions へエージェント所属先の宣言列（additive）
-- 対象DB: personal-os-board（sessions は既存テーブル）。
-- 適用（人間ゲート）: turso db shell personal-os-board < このファイル
-- 注意: ALTER TABLE ADD COLUMN は再実行すると duplicate column エラーになる（1回だけ流す）。
--
-- 設計（子計画09 方針6・2026-07-19改定）:
--   セッションの所属先（テーマ›タスク or 新見出し）を、プロンプト登録時にAIが
--   board.py update --todo <id> [--theme <id>] で宣言し、ここへ保存する。
--   エージェント行の人間チェックは、この宣言済み todo_id を「読むだけ」で格納先を判定する
--   （判定を再作成しない・宛先を創作しない）。状態機械（run/wait/sub）はこの列で書き換わらない。
--   todo_id は inbox DB の todos.id を指す参照値（cross-DBのため外部キーは張らない）。

ALTER TABLE sessions ADD COLUMN todo_id TEXT;   -- 宣言済み所属タスク（inbox todos.id・NULL=未宣言→新見出し）
ALTER TABLE sessions ADD COLUMN theme_id TEXT;  -- 宣言済み所属テーマ（inbox themes.id・任意）
