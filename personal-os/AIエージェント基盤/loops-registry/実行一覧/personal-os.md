# 実行一覧 — personal-os

このMDは、現在 `loops-registry/loops/` に置く現役global loopのcurrent overview正本。
廃止履歴と生ログは載せず、実機のloaded/disabledは `launchctl print` で確認する。

最終全体確認: 2026-07-11 11:46 JST。下記4 labelがloaded、削除対象5 loopは未ロードと実測。

## 現役loop（4本）

<!-- LOOP:board-reconcile -->
### `board-reconcile`
- 目的: session-boardの生存照合を5分ごとに補完し、沈黙した稼働表示を停止へ戻す
- 発火: StartInterval 300秒（5分）
- 発火設定: {"StartInterval":300}
- runner: script
- launchd label: com.kitamura.board-reconcile
- 正本: ../loops/board-reconcile/loop.md
- 意図状態: 稼働中
- 最終実機確認: 2026-07-11 11:46 JST loaded

<!-- LOOP:board-sweep -->
### `board-sweep`
- 目的: 当日・前日の停止行を安全弁つきで判定し、確実に完了した行だけを完了へ流す
- 発火: StartInterval 3600秒（60分）
- 発火設定: {"StartInterval":3600}
- runner: script
- launchd label: com.kitamura.board-sweep
- 正本: ../loops/board-sweep/loop.md
- 意図状態: 稼働中
- 最終実機確認: 2026-07-11 11:46 JST loaded

<!-- LOOP:daily-notion-sync -->
### `daily-notion-sync`
- 目的: 当日デイリーの稼働中・完了情報を表示専用のNotion表へミラーする
- 発火: StartInterval 30秒
- 発火設定: {"StartInterval":30}
- runner: script
- launchd label: com.kitamura.daily-notion-sync
- 正本: ../loops/daily-notion-sync/loop.md
- 意図状態: 稼働中
- 最終実機確認: 2026-07-11 11:46 JST loaded

<!-- LOOP:session-record-prune -->
### `session-record-prune`
- 目的: 保持30日を超えたClaude・Codexセッション記録を内蔵ディスク上のTrashへ移す
- 発火: StartCalendarInterval 月・水・金 18:00（システムTZ）
- 発火設定: {"StartCalendarInterval":[{"Weekday":1,"Hour":18,"Minute":0},{"Weekday":3,"Hour":18,"Minute":0},{"Weekday":5,"Hour":18,"Minute":0}]}
- runner: script
- launchd label: com.kitamura.session-record-prune
- 正本: ../loops/session-record-prune/loop.md
- 意図状態: 稼働中
- 最終実機確認: 2026-07-11 11:46 JST loaded

## 実態確認

```sh
for label in \
  com.kitamura.board-reconcile \
  com.kitamura.board-sweep \
  com.kitamura.daily-notion-sync \
  com.kitamura.session-record-prune
do
  launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1 \
    && echo "loaded $label" \
    || echo "not-loaded $label"
done
```

構成変更後は、このディレクトリで `python3 verify.py --write-html && python3 verify.py` を実行する。
