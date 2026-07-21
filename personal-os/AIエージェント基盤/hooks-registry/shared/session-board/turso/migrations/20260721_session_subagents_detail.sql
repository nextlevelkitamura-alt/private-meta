-- 子03「サブエージェント詳細化」: session_subagents へ「中身」を持たせる詳細5列を追加する
-- 対象DB: personal-os-board（sessions と同じboard DB・既存テーブル session_subagents へのADD COLUMNのみ）
-- 前提: 20260719_session_subagents.sql 適用済み（このテーブルが既に在ること）。
-- 適用（人間ゲート）: turso db shell personal-os-board < このファイル
-- 注意: SQLite/libSQL の ALTER TABLE ADD COLUMN は IF NOT EXISTS を持たない＝再実行不可。
--   既に列がある状態でこのファイルを流すと "duplicate column" で失敗する（冪等ではない）。
--   適用は1回だけ。適用済みか不明な時は先に `PRAGMA table_info(session_subagents);` で確認する。
--
-- 設計（子計画03 方針・完了条件）:
--   「サブN体」の個体行に、どのruntime/どのモデル/どの種別/どう起動されたか/何を頼んだかを載せる。
--   捕捉2経路（Claude=PreToolUseスプール→SubagentStart enrich／Codex=直接exec駆動の呼び出し規律）が
--   board.py sub-start の新引数（--runtime/--model/--type/--via/--prompt）へ渡し、ここへ書き込む。
--   全列 NULL 許容＝詳細が取れなくても running 行は積める（後方互換・沈黙故障で本体を止めない）。
--   prompt は全文TEXT格納・UIは折りたたみ・board.py 側で簡易マスキング後に保存する（secret取りこぼし防止優先）。

ALTER TABLE session_subagents ADD COLUMN runtime    TEXT;  -- claude | codex（起動ランタイム）
ALTER TABLE session_subagents ADD COLUMN model      TEXT;  -- opus | sonnet | ...（種別から推測不能なケースを漏らさない独立列）
ALTER TABLE session_subagents ADD COLUMN agent_type TEXT;  -- subagent_type（reviewer / general-purpose / impl-opus 等）
ALTER TABLE session_subagents ADD COLUMN launch_via TEXT;  -- agent-tool | exec | headless（どう起動したか）
ALTER TABLE session_subagents ADD COLUMN prompt     TEXT;  -- 渡したプロンプト全文（マスキング後・UIは1行要約＋折りたたみ）
