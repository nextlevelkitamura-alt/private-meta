# 実行一覧 — nextlevel-career（`com.nextlevel.*`）

- 正本（詳細）: `~/Private/projects/active/仕事/領域/整備/自動実行/マニュアル/自動実行一覧.md`
- 月別自動処理: `~/Private/projects/active/仕事/scripts/staff-status/MONTHLY-SCHEDULE.md`
- 実態確認: `bash ~/Private/projects/active/仕事/scripts/launchd/status.sh`
- plist 管理: `仕事/scripts/launchd/install.sh core|all`

## どのようなことを自動実行しているのか

e-nextlevel（求人管理画面）を Playwright で操作し、Google スプレッドシートを源に「求人の巡回/更新・ワーカー探索・エントリー時限処理・認証維持」を無人実行する。`com.nextlevel.dispatcher`（60秒）が内部タスクを時刻・ロックで巡回する **dispatcher 1本化**構成。

## ジョブ（簡易・詳細と稼働状態は正本/`status.sh`）

| ジョブ | だいたい | 何をする |
|---|---|---|
| dispatcher | 60秒 | 司令塔。下記を内部で巡回起動 |
| entry-schedule | 随時 | シートの時限タスク行を実行 |
| job-update | 15分 | 求人を管理画面で一括更新 |
| job-patrol | 月金・昼 | 求人を巡回スクレイプ→月別シート最新化 |
| monthly-schedule-generator | 月1 | 翌月の `{月}月自動処理` タブを作成 |
| worker-search（関東/全国） | 常駐 | ワーカー検出→監視シート追記 |
| auth-morning / keep-alive | 平日朝 | ログインセッション（`auth.json`）維持 |

> - 稼働状態（loaded/disabled）は変動が激しいので**ここに書かない** → `status.sh` で確認する。
> - 内部タスク条件・データ源シート名・1日テンプレ・変更履歴は**正本**を見る（二重管理しない）。
