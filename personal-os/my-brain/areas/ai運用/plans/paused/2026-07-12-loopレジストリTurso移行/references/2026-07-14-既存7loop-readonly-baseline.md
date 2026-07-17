# 既存7 loop 読み取り専用 baseline

取得日時: 2026-07-14 19:00:51 JST

目的: Turso import・canary・launchd変更の**前**に、現行の定義と実機状態を比較できるようにする。
実行したこと: `launchctl print` と `plutil -lint` の読み取りのみ。bootstrap / bootout / enable / disable / plist書換 / script実行はしていない。

## snapshot

| loop | launchd label | 実機状態 | 発火 | runs / last exit |
|---|---|---|---|---|
| board-reconcile | `com.kitamura.board-reconcile` | loaded・待機中 | 300秒 | 107 / 0 |
| board-sweep | `com.kitamura.board-sweep` | loaded・待機中 | 3600秒 | 8 / 0 |
| daily-notion-sync | `com.kitamura.daily-notion-sync` | unloaded（意図した安全停止） | 復帰承認後30秒 | — |
| session-record-prune | `com.kitamura.session-record-prune` | loaded・待機中 | 月・水・金 18:00 | 0 / never exited |
| nextlevel-dispatcher | `com.nextlevel.dispatcher` | loaded・待機中 | 60秒 + RunAtLoad | 532 / 0 |
| worker-search-kanto | `com.nextlevel.worker-search.schedule` | loaded・実行中 | 240秒 + RunAtLoad | 97 / 0 |
| worker-search-zenkoku | `com.nextlevel.worker-search.zenkoku` | loaded・実行中 | 240秒 | 88 / 0 |

`loaded・待機中` は launchd の `state = not running` を「停止」と誤読しない表現である。次の予定時刻を待っている正常状態を含む。

## 定義ファイルの確認

上記7本のplistはすべて `plutil -lint` で構文OKだった。実体の正本path、内部処理、Notion停止理由は
`AIエージェント基盤/loops-registry/実行loop一覧.md` を参照する。生ログ、credential、個人情報は取得・記録していない。

## 移行時の比較手順

1. Tursoへimportする前に、この表と `実行loop一覧.md` からlabel・発火・scope・source referenceを照合する。
2. import後もlaunchdの変更前は、`launchctl print` のloaded状態、run interval、runs、last exitを再取得して差分を確認する。
3. `daily-notion-sync` はP0安全停止中であり、Notion API書込み、launchd復帰、canaryの対象にしない。独立レビューと人間承認が先である。
4. canary applyとrollbackは、program子04の人間ゲート後にだけ実施する。
