-- stuck-wait.sql — 最新イベントが wait のまま15分を超えているセッション一覧（放置検知）
-- 使い方: turso db shell personal-os-board < queries/stuck-wait.sql
-- 完了(done)・復帰(run/sub)済みのセッションは出ない。board-sweep（完了自動判定loop）の
-- 発火条件・夜会の拾い漏れ確認の入力を想定。閾値15分は板の幽霊枠掃除（STALE_MIN_NOFILE）と同じ。
-- 'now' の '+9 hours' 固定の理由は session-durations.sql の注記を参照。
SELECT
  session_key,
  goal,
  repo,
  at AS waiting_since,
  CAST(ROUND((JULIANDAY(DATETIME('now', '+9 hours')) - JULIANDAY(at)) * 1440) AS INTEGER) AS wait_min
FROM (
  SELECT
    session_key, goal, repo, state, at,
    ROW_NUMBER() OVER (PARTITION BY session_key ORDER BY at DESC, id DESC) AS rn
  FROM session_events
)
WHERE rn = 1
  AND state = 'wait'
  AND (JULIANDAY(DATETIME('now', '+9 hours')) - JULIANDAY(at)) * 1440 > 15
ORDER BY at;
