-- session-durations.sql — セッション別の実行/待ち/サブ時間（分）を session_events から集計
-- 使い方: turso db shell personal-os-board < queries/session-durations.sql
-- 区間 = 各イベントの at から同一セッションの次イベントの at まで（LEAD窓関数・sqlite 3.25+）。
-- 最後のイベント（未終了セッション）は現在時刻で止める（now止め）。done は終端マーカー（区間を持たない）。
-- 1区間は720分(12h)で頭打ち＝イベント欠損・クロック異常の暴走抑止。負区間は0（クロック逆行ガード）。
-- 'now' は常にUTC基準・at はJST naive保存のため '+9 hours' 固定でJST化
-- （Tursoサーバ／ローカルsqlite3のどちらで評価しても同じ結果になる。TZ移住時はここを直す）。
SELECT
  session_key,
  MAX(last_goal) AS goal,
  MIN(session_date) AS session_date,
  CAST(ROUND(SUM(CASE WHEN state = 'run'  THEN mins ELSE 0 END)) AS INTEGER) AS run_min,
  CAST(ROUND(SUM(CASE WHEN state = 'wait' THEN mins ELSE 0 END)) AS INTEGER) AS wait_min,
  CAST(ROUND(SUM(CASE WHEN state = 'sub'  THEN mins ELSE 0 END)) AS INTEGER) AS sub_min
FROM (
  SELECT
    session_key, session_date, state,
    LAST_VALUE(goal) OVER (
      PARTITION BY session_key ORDER BY at, id
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_goal,
    MAX(0, MIN(720,
      (JULIANDAY(COALESCE(
         LEAD(at) OVER (PARTITION BY session_key ORDER BY at, id),
         DATETIME('now', '+9 hours'))) - JULIANDAY(at)) * 1440
    )) AS mins
  FROM session_events
)
WHERE state IN ('run', 'wait', 'sub')
GROUP BY session_key
ORDER BY session_date, session_key;
