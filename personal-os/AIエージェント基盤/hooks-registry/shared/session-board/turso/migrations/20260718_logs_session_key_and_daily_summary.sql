-- 調整1+3（2026-07-18・DB書き込み計画で人間GO済み）
-- 対象DB: personal-os-board
-- 適用: turso db shell personal-os-board < このファイル
-- 注意: ALTER TABLE ADD COLUMN は再実行すると duplicate column エラーになる（1回だけ流す）。

-- 調整1: 「終わったこと」をセッションへ紐付ける列
ALTER TABLE session_logs ADD COLUMN session_key TEXT;

-- 調整3: 日次サマリview（実行分・待ち分・sub分・稼働セッション数・成果ログ件数を日付ごと1行に）
CREATE VIEW IF NOT EXISTS daily_summary AS
SELECT
  session_date,
  CAST(ROUND(SUM(CASE WHEN state = 'run'  THEN mins ELSE 0 END)) AS INTEGER) AS run_min,
  CAST(ROUND(SUM(CASE WHEN state = 'wait' THEN mins ELSE 0 END)) AS INTEGER) AS wait_min,
  CAST(ROUND(SUM(CASE WHEN state = 'sub'  THEN mins ELSE 0 END)) AS INTEGER) AS sub_min,
  COUNT(DISTINCT session_key) AS sessions,
  (SELECT COUNT(*) FROM session_logs l WHERE l.session_date = d.session_date) AS done_logs
FROM (
  SELECT
    session_key, session_date, state,
    MAX(0, MIN(720,
      (JULIANDAY(COALESCE(
        LEAD(at) OVER (PARTITION BY session_key, session_date ORDER BY at, id),
        CASE WHEN session_date = DATE('now', '+9 hours')
             THEN DATETIME('now', '+9 hours')
             ELSE DATETIME(session_date, '+1 day') END
      )) - JULIANDAY(at)) * 1440
    )) AS mins
  FROM session_events
) d
WHERE state IN ('run', 'wait', 'sub')
GROUP BY session_date;
