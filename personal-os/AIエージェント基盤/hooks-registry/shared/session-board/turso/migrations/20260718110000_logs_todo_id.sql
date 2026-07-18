-- 子05 段階3: 「終わったこと」ログを、やること（inbox の todos.id）へ紐付ける列。
-- 対象DB: personal-os-board（session_logs は既存テーブル）。
-- 適用: turso db shell personal-os-board < このファイル
-- 注意: ALTER TABLE ADD COLUMN は再実行すると duplicate column エラーになる（1回だけ流す）。
--
-- session_logs は board DB、todos は inbox DB にあるため DB を跨いだ外部キーは張れない。
-- todo_id は「どの todo の成果か」を後から de-dup / サマリ集約するための参照値（任意）。

ALTER TABLE session_logs ADD COLUMN todo_id TEXT;
