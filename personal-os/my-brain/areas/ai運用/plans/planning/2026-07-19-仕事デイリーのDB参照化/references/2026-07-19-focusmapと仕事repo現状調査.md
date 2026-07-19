# Focusmapと仕事repoの現状調査（2026-07-19スナップショット）

「本日やること」に関わる2repoの現状。子計画立案の材料。生きた実装と食い違ったら実装側が正。

## Focusmap側（projects/active/focusmap）

### 「今日のタスク」に関わるテーブル（Supabase）

| テーブル | 用途 |
|---|---|
| `tasks` | アプリ本体のタスク。Todayパネルの実体。「今日」専用フラグは無く **`scheduled_at` が当日レンジに入るか**で判定。`status`(todo/in_progress/done), `stage`, `priority`, `is_habit`, `deleted_at`(論理削除) 等 |
| `ai_todo_progress` | 外部Claude Codeセッションの当日Todoミラー。`session_date`, `task_title`, `task_status`, `source`(claude_code/schedule_md)。仕事repoのai-todo-syncの書き込み先 |
| `ai_tasks` | AI実行ジョブのキュー（Codex/Playwright実行）。「今日やること」ではない別物 |

`tasks` と `ai_todo_progress` は**自動連携していない**。アプリ画面（Todayパネル）が見ているのは `tasks`。

### 外部からの読み取り経路

1. **HTTP API v1**: `GET /api/v1/tasks?status=todo`（日付フィルタ無し→クライアント側で当日絞り込み）、`GET /api/v1/ai/todos?date=YYYY-MM-DD`。認証は Bearer APIキー（`sk_focusmap_` プレフィックス、SHA-256ハッシュ照合、スコープ制）。`ai_todos:read/write` は公開プリセット外の準内部スコープで手動付与が要る。`tasks` は `tasks:read/write`。
2. **MCPサーバー `shikumika`**（stdio）: `shikumika_today_summary`（当日分を整形して返す）、`shikumika_task_list` 等。Supabase service_role + `SHIKUMIKA_USER_ID` をenvで直接受けてテーブル直読み。
3. 書き込み同期: `POST /api/v1/ai/todos/sync`（当日分を全削除→一括insertするフルステート同期）。

MCPは接続すると全ツールスキーマがセッション常駐となり数千トークンを固定消費するため、**デイリー取得用途はCLI/API（curl 1本）を既定とする**（設計結論参照）。

## 仕事repo側（projects/active/仕事）

### 「本日やること」の現状＝三重化

1. **`スケジュール/YYYY-MM/schedule.md`**（正本のはず）: `/task` スキルが起動時必読・直接編集する。**ただし当月2026-07のファイルは未作成**で、md正本運用は破綻気味。フォーマット定義は `領域/整備/タスク/マニュアル/schedule-format.md`。
2. **`/morning` は別ソース**: 「今日やること」をスプシ管理表F列＋Google Calendarから組み立てる（schedule.mdを読まない）。
3. **Focusmapへの一方向同期**: `scripts/ai-todo-sync/` が schedule.md をパースし `POST /api/v1/ai/todos/sync` へ送る（`/task`・`/eod` から呼び出し）。つまり現状は「md正本→Focusmapは写し」。

### その他の前提

- schedule.md を毎日自動生成する仕組みは無い（スキルが「無ければ作る」と書いてあるだけ）。
- `.codex/hooks.json` の TodoWrite フックが ai-todo-sync を自動発火するが、コマンドパスがMac絶対パス直書き。hooks運用の壊れやすさの前例として留意。
- 外部サービス接続の説明は `方針/api-reference.md` に集約する規約がある（契約mdの置き場所判断の根拠）。

## personal-os側の関連事実

- デイリー正本は `my-brain/ゴール/デイリー/YYYY/MM/YYYY-MM-DD.md`（1日1枚・8節）。盤面（session-board）が「動いているエージェント/終わったこと」区画を管理。
- loops-registry の implementation-links に「状態の正本は移行期間後 Turso / Focusmap を正とする」と明記済み。DB正本化はpersonal-osが既に予定している路線。
- 仕事repoのAGENTS.mdには Personal OS標準への「薄い接続」（plan-triage経由の入口判断等）が2026-07-02から入っている。
