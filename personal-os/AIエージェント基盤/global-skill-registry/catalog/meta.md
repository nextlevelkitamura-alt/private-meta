# メタスキル / global

Globalのメタスキル索引。正本は `skills/`、作成・移行・削除履歴は `logs/` を見る。

## スキル名: `coding-task-orchestrator`
概要: 開発依頼の意図確認、作業規模分類、実行面、branch/worktree、docs lifecycle、worker prompt、進捗監督を整理する。
近接・注意: coding作業に特化。入口の規模/経路判断は `plan-triage`、実行中の監督は `cockpit-supervisor`（旧上位監督 `agent-task-orchestrator` は2026-07-03削除・決定ログ#8）。

## スキル名: `cockpit-supervisor`
概要: cockpit運用の指揮官（監督）判断手順。見張り番WAKE理由別のアクション、構成カード、2ペイン既定/3ペイン例外、差し戻し上限、見張り番運用標準を定める。
近接・注意: 機構は `orca-cockpit`（相互ポインタ）。段階・規模・ゲートの正本は 説明書/運用契約.md §2。

## スキル名: `grill-me`
概要: 計画や設計を一問ずつ深掘りし、共有理解、分岐、依存関係を整理する。
近接・注意: 実装や作成ではなく、問いで設計を詰める。

## スキル名: `handoff-plan-supervisor`
概要: 受け取った内容を全体計画へ整理し、添付素材を確認して引き継ぎ書＋別チャット実装用プロンプトを作り、戻り報告の進捗評価・監督を行う。
近接・注意: 実装の統括は `coding-task-orchestrator`、設計の深掘りは `grill-me`。引き継ぎ生成に特化。

## スキル名: `inbox-triage`
概要: 当日デイリーの依頼インボックス行を収集・重複集約し、トリアージ結果マーカー（計画作成済み/処理中/重複/サクッと判定）を付けて起案までつなぐ。実行はしない。
近接・注意: 規模・経路・起動形・モデルの判断基準は `plan-triage` を参照（本文に基準を持たない）。巡回の機構は loops-registry/loops/inbox-patrol。runtime露出はしない（headless専用: patrol.shがSKILL.md正本パスを直接渡すため露出不要・2026-07-03記録）。

## スキル名: `kickoff`
概要: 起票ゲート＝作業の既定の入口。デイリー依頼インボックスへ1行起票（出所つき）→構造3条件の軽量判定→サクッと=即実行GO／ライト以上=起案して全体管理者の采配へ。
近接・注意: 判定基準は `plan-triage`（本文に基準を持たない・サクッとはゲート内処理を1行起票+3条件判定に制限）。行注記語彙の正本は loops-registry/loops/inbox-patrol/loop.md。Notionインボックスは例外入口（子03経路）。

## スキル名: `morning-routine`
概要: 朝会（usage確認→全repo進捗把握→壁打ち→指揮官数・役割分担→ロースター更新→指揮官プロンプト生成→TODO更新）と夜会（18:30/23:30・状況報告・消し込み・明日へ＋逆算チェック）の定型。
近接・注意: 管轄共有の正本は説明書/指揮官ロースター.md、規模・ゲートは運用契約§2（本文に基準を持たない）。入口判断は `plan-triage`、監督は `cockpit-supervisor`。旧 my-brain/ゴール/朝夜ルーティン.md は吸収済み（ポインタ化・2026-07-03）。

## スキル名: `naiyou-suriawase`
概要: 作業開始前に、依頼理解、ゴール、曖昧点、確認質問を短く整理する。
近接・注意: 最小の事前すり合わせ。深掘りは `grill-me`。**明示依頼時のみ発動**（似た文脈でも勝手に反応しない・2026-07-03ユーザー裁定）。すり合わせ結果は `plan-triage` の入力へ引き継ぐ（既答の質問を繰り返さない）。

## スキル名: `orca-cockpit`
概要: Orca CLIで「実装/レビュー」既定2ペイン（計画+監督は計画未成熟時のみ3ペイン目）の分割コックピットを構築・駆動する。決定的部分は scripts/cockpit.sh と watch.sh（見張り番）。`spawn` で既存repoに1ペインを高速起動（--no-mcp・プロンプトを起動引数へ畳み込み送信レース無し）も可能。
近接・注意: cockpit監督の判断手順は `cockpit-supervisor`。「いつOrcaを使うか」の判断は `coding-task-orchestrator`。本Skillは実行機構。

## スキル名: `plan-ops`
概要: 計画ライフサイクルの機械手続き（program.md子マップの機械書換progctl・テンプレ正本からの雛形生成scaffold・静的整合チェックprogram-lint・ai-jobs run-cardの状態遷移）を固定パスscriptで安全に回す。中身の判断はしない。
近接・注意: 何をやるか/どう直すかの判断は `plan-triage`（入口）/ `coding-task-orchestrator` / `grill-me` へ委譲。Skillライフサイクルは `skill-creator-custom`、repo新規/整備は `repo-create`。

## スキル名: `plan-triage`
概要: 「やりたいこと」1件の入口判断。規模（サクッと/ライト/フル）・経路（repo/指揮官）・起動形（2ペイン既定）・モデルを1回で決め、構成カード1枚にしてレーンへ流す。
近接・注意: 語彙・基準の正本は運用契約§2・決定ログ#3・`cockpit-supervisor` への参照（独自定義なし）。巡回起案の `inbox-triage` はこのスキルを参照する側。実行中の監督判断は `cockpit-supervisor`。

## スキル名: `repo-create`
概要: repoを新しく作る、または既存repoを評価してAIが作業しやすい状態へ整える。
近接・注意: repo系入口。Skill削除/改名/移行は `skill-creator-custom` / `skill-delete`、repo物理移動は `repo-relocation`。

## スキル名: `repo-relocation`
概要: 既存repoを別フォルダへ移動し、旧パス互換symlinkを残さず、参照更新、launchd再登録、移動後テスト、repo-registry記録まで扱う。
近接・注意: `repo-create` は新規repo/初期設定用。既存repoの物理移動はこのSkill。

## スキル名: `skill-creator-codex`
概要: Codex向けSkillの新規作成、更新、bundled resources、`agents/openai.yaml`、quick_validateを支援する。
近接・注意: Codex仕様寄り。ライフサイクル判断は `skill-creator-custom`。

## スキル名: `skill-creator-custom`
概要: Skill作成、改善、レビュー、横断スキャン、移行、改名、削除、runtime露出、logs確認の窓口になる。
近接・注意: Skillライフサイクル全体の入口。Global / repo-local の重複・矛盾確認もここから始める。Codex専用Skill（`openai.yaml`/`quick_validate`）の作成・更新は `skill-creator-codex` へ委譲（相互ポインタ・2026-07-03監査改修）。段階runtime露出は作成/移行ログの `未露出バックログ:` 行で追跡（`logs/AGENTS.md` §2）。

## スキル名: `skill-delete`
概要: Skill削除前に対象path、runtime露出、参照、削除理由、人間承認を確認する安全ゲート。
近接・注意: 削除専用。通常相談は `skill-creator-custom`。

## スキル名: `skill-visualizer`
概要: Skillのworkflow、構造、リスク、図解、画像生成プロンプトを整理する。
近接・注意: Skill理解用のメタ成果物を作るため `meta` に分類。

## スキル名: `task-router`
概要: 既存 `docs/ai` 運用repo向けのlegacy互換ルーター。開発依頼を即実装、順次、readonlyサブエージェント、複数Codexチャット、worktreeへ振り分ける。
近接・注意: 新しいPersonal OS/repo横断docs標準ではない。新規設計や確認優先なら `coding-task-orchestrator`、要件・矛盾・実装整合は `requirements-governor`、repo/AGENTS整備は `repo-create`。

## スキル名: `ui-ux-pro-max`
概要: Web/モバイルのUI/UX設計知能。50+スタイル・161カラーパレット・フォント対・製品タイプ・UXガイド・チャートを10スタック（React/Next/Vue/Svelte/SwiftUI/RN/Flutter/Tailwind/shadcn/HTML）で持ち、UI/UXのplan/build/design/review/fixを支援する。
近接・注意: デザイン提示・レポートのHTML化は `html`。設定/管理画面に特化した設計観点も含む。

