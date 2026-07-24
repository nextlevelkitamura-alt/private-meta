# Focusmapの保存・参照設計

この文書は、「計画システム再設計」テーマにおけるデータ保存先と参照境界の正本である。今回は計画資料だけを扱い、DB migration、R2バケット、credential、Focusmapアプリは変更しない。

## 決定

| 保存先 | 正本にするもの | 置かないもの |
| --- | --- | --- |
| Git管理されたローカル資料 | `goal.md`、DB・UIの設計本文、採用理由、決定、参照先の意味 | セッションの現在状態、毎回変わる実行履歴 |
| Focusmap / Turso | Theme・Topicの短い現在地、Session・活動の短い状態と履歴、Git/R2への参照 | 長文設計のコピー、画像本体、credential |
| R2 | 採用済みモック画像、共有する画像・HTMLなどの大きい成果物 | 生成途中の案、編集途中の画像、長文設計の正本 |
| ローカル作業領域 | 生成途中の画像・モック・HTML | 採用後に他環境から参照すべき唯一の成果物 |

Gitとローカル資料は別々の正本ではない。同じGit管理ファイルをローカルで編集し、commitで履歴と共有可能な版を確定する。DBにはその本文を再編集可能な形で複製せず、必要な時にGit参照から読む。

## 現状（2026-07-25に実装を確認）

### すでに存在するもの

- FocusmapのTursoには、`themes`、日ごとの採用状態を持つ`theme_days`、完了条件を持つ`theme_completion_criteria`、ThemeとPlan・repoのリンクがある。Themeは名前・目的・完了条件などの短い運用データとして実装されている。
- session-boardは別のboard DBに`session`、`session_events`、`session_logs`、`session_subagents`、実行Context、分類提案を記録し、Focusmapが「動いているエージェント」「終わったこと」をDBから描画する。
- Git上の計画MarkdownをTursoの`plan_docs` / `plan_progress`へ一方向同期する`plansync`がある。Markdownが正本で、DB側は表示キャッシュという境界になっている。
- R2向けのサーバー専用clientと、スクリーンショットのthumbnail / previewをアップロード・署名URL取得・削除するAPIがある。Tursoの`screenshots`にはR2 object keyや寸法、サイズ、取得時刻などを保存する。

### 現状と今回の決定の差

- 現行`plan_docs.body`は計画Markdown全文を表示キャッシュとして保持している。今回の決定は、今後のTheme・Topic設計本文をこの方式で増やさず、DBは短い状態と参照に寄せることである。既存`plan_docs`の廃止・縮小は今回行わず、別の実装判断にする。
- 現行R2経路はCodex監視のスクリーンショットpreview用途である。採用済みモック画像やHTMLを共通成果物として登録する汎用artifact機能は、実装済みとは確認できていない。
- `Topic`をTheme配下の独立した運用単位として保存するschemaと、下記の活動履歴schemaは未確定である。

## Git管理資料に残す内容

- 全体目的と達成条件
- DB・UIの設計本文と判断理由
- 採用案・不採用案と、その判断日
- R2成果物が何を表すか、なぜ採用したか
- 関連するMarkdown / HTML / 実装ファイルの位置
- DBから参照するためのrepo、相対path、commit

画像そのものをGitへ必須にはしない。画像の意味、採用理由、関連する正本MarkdownまたはHTMLはGitへ残す。HTMLが設計の正本になる場合はMarkdown側を正本とし、HTMLは表示成果物として扱う。

## Focusmap / Tursoに残す内容

### Theme・Topicの短い現在地

- 名前、短い目的、状態、並び順
- 完了条件の項目とチェック状態
- 今日・週・月のどこで扱うか
- 関連repo、Git文書、採用済みartifactへの参照

Topicの本文はDBに持たず、「現在何を検討しているか」「次に何を判断するか」が一覧で分かる短文に留める。

### 活動履歴の最小案（未実装）

活動1件で「誰が、いつ、何を変え、何を参照し、どうなったか」を短く追える形にする。

| 項目 | 役割 |
| --- | --- |
| `activity_id` | 活動の一意ID |
| `theme_id` / `topic_id` | 活動の所属。該当しない方はNULL |
| `occurred_at` | 発生時刻 |
| `actor_type` | `human` / `model` / `agent` / `hook` |
| `actor_ref` | モデル名または担当名の短い識別子 |
| `action` | `created` / `updated` / `adopted` / `linked`などの短い種別 |
| `summary` | 作成・変更した内容の短い要約 |
| `result_status` / `result_summary` | 成否と短い結果 |
| `session_id` | 関連Session。無ければNULL |
| `git_ref_id` / `artifact_id` | GitまたはR2参照。無ければNULL |

Prompt全文、長い会話、長文計画、コマンド出力、credentialは活動履歴に入れない。既存の`session_events` / `session_logs` / AI activityを再利用するか、Theme・Topic用の活動表を分けるかは、schema実装前に決める。

## R2参照の最小メタデータ案（未実装）

| 項目 | 役割 |
| --- | --- |
| `artifact_id` | 成果物の一意ID |
| `owner_type` / `owner_id` | Theme、Topic、活動などの所属 |
| `object_key` | R2内の保存キー。署名URLは保存しない |
| `artifact_kind` | `mock_image` / `shared_image` / `html`など |
| `content_type` | MIME type |
| `size_bytes` | サイズ |
| `content_hash` | 内容同一性の確認 |
| `adopted_at` | 採用確定時刻 |
| `activity_id` | 採用・更新した活動への参照 |

R2はprivateを前提に、表示時だけ期限付きURLを生成する。bucket名、object key規則、世代管理、削除・置換ルールは実装前に決める。接続情報や署名済みURLはDB・Gitへ保存しない。

## Git参照の最小メタデータ案（未実装）

| 項目 | 役割 |
| --- | --- |
| `git_ref_id` | 参照の一意ID |
| `repo_slug` | repoの安定した識別子 |
| `relative_path` | repo rootからの相対path |
| `commit_sha` | 参照した版。現在版だけならNULLを許容するか要決定 |
| `content_hash` | 内容同一性の確認 |
| `ref_kind` | `goal` / `design` / `decision` / `implementation`など |
| `title` | UI表示用の短い名前 |

ローカル絶対pathやGitHub URLを正本値にしない。repo識別子・相対path・commitから、実行環境に応じてローカルpathまたはGitHub URLを組み立てる。

## 参照の流れ

1. Focusmapの一覧はTursoからTheme・Topic・活動の短い現在地だけを読む。
2. 詳細な判断が必要な時だけ、Git参照から該当Markdownを読む。
3. 採用済みの画像・HTMLを見る時だけ、R2の期限付き参照を取得する。
4. 生成途中の成果物はローカルに留め、採用時に意味と理由をGitへ、共有物をR2へ登録する。

これにより毎Promptで長文を読む必要はない。Session開始時は短い現在地を1回取得し、詳細が必要なTopicだけGit資料を追加取得する。

## 今回の非対象

- Turso schema migrationと既存表の変更
- R2 bucket作成、objectのupload、credential設定
- Focusmap API・画面・hook・同期処理の実装
- 既存`plan_docs`表示キャッシュの廃止
- UI topicの設計

## 実装前に残る判断

1. Topicを独立tableにするか、Theme内の軽い見出しとして始めるか。
2. 活動履歴を既存session / AI activityから導出するか、Theme・Topic用に新設するか。
3. Git参照を「常にcommit固定」にするか、「現在path」と「採用commit」を分けるか。
4. R2のobject key規則、version、置換・削除、private配信の権限境界。
5. HTMLはMarkdownから生成する表示物だけにするか、単独成果物も許可するか。
6. 既存`plan_docs.body`をいつ参照中心へ縮小するか。

## 実装確認に使った正本

- `projects/active/focusmap/db/turso/migrations/20260719000000_themes_and_carryover.sql`
- `projects/active/focusmap/db/turso/migrations/20260724000000_theme_days_plan_links.sql`
- `projects/active/focusmap/db/turso/migrations/20260605000000_codex_monitoring.sql`
- `projects/active/focusmap/src/lib/r2/client.ts`
- `projects/active/focusmap/src/app/api/screenshots/`
- `personal-os/AIエージェント基盤/hooks-registry/shared/session-board/AGENTS.md`
- `personal-os/AIエージェント基盤/hooks-registry/shared/session-board/turso/migrations/`
- `personal-os/AIエージェント基盤/skills/plan-ops/scripts/plansync.py`

これらは現行実装の確認先であり、この文書が各実装の正本を置き換えるものではない。
