-- daily-totals.sql — 指定日（:date 例 '2026-07-11'・未指定NULLなら当日JST）の日次合計時間（分）
-- 使い方(当日分): turso db shell personal-os-board < queries/daily-totals.sql
--   ※ shell が未バインド :date をエラーにする場合は、:date を '2026-07-11' 等へ置換して実行
--   （例: sed "s/:date/'2026-07-11'/g" queries/daily-totals.sql | turso db shell personal-os-board）。
--   Python sqlite3 等からは {"date": "YYYY-MM-DD"} をバインドする。
-- 区間の定義（LEAD・now止め・720分上限・負区間0・'+9 hours'）は session-durations.sql と同じ。
-- 既知の限界: 日を跨いだセッションは session_date（イベントを打った日）で日ごとに切れ、
-- 跨ぎ区間の LEAD が日内に無いため now止めになる（720分上限で暴走は抑止）。
SELECT
  session_date,
  CAST(ROUND(SUM(CASE WHEN state = 'run'  THEN mins ELSE 0 END)) AS INTEGER) AS run_min,
  CAST(ROUND(SUM(CASE WHEN state = 'wait' THEN mins ELSE 0 END)) AS INTEGER) AS wait_min,
  CAST(ROUND(SUM(CASE WHEN state = 'sub'  THEN mins ELSE 0 END)) AS INTEGER) AS sub_min,
  COUNT(DISTINCT session_key) AS sessions
FROM (
  SELECT
    session_key, session_date, state,
    MAX(0, MIN(720,
      (JULIANDAY(COALESCE(
         LEAD(at) OVER (PARTITION BY session_key ORDER BY at, id),
         DATETIME('now', '+9 hours'))) - JULIANDAY(at)) * 1440
    )) AS mins
  FROM session_events
  WHERE session_date = COALESCE(:date, DATE('now', '+9 hours'))
)
WHERE state IN ('run', 'wait', 'sub')
GROUP BY session_date;
