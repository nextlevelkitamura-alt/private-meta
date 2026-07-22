---
name: morning-routine
description: 朝会と夜会の定型手順。朝会=usage確認→前日/当日デイリーとactive計画の確認→人間との優先順位・実行形の決定→起動プロンプト生成→当日TODO更新。夜会=当日デイリーを基に状況報告・TODO消し込み・明日への引継ぎと逆算確認。Use when ユーザーが「おはよう」「朝会」「朝のルーチン」「モーニングルーティン」「朝会して」と言った時（朝会モード）、または「夜会」「今日の締め」「おつかれ」「締めて」と言った時（夜会モード）。
---

# morning-routine（朝会と夜会）

1日の始まりと締めの定型。状態・担当・モデルの本文は持たず、既存の正本を読む順と手順だけを持つ（scriptなし）。

正本ポインタ（本文に複製しない）:

- 当日の状態・担当・実行ログ（動いているエージェント／終わったこと）: board DB（Turso）が正本。`board.py show` か focusmap（DBから描画）で読む。デイリーmdには無い（2026-07-21 正本反転・案b）。前日ログとactive計画の工程進捗の決定的収集は `../daily-start/scripts/fetch-context.sh`（`yesterday_session_logs`／`active_plans`）
- デイリーmd（`my-brain/ゴール/デイリー/<年>/<月>/<日>.md`）は人間記入節（今日すること・依頼インボックス・質問キュー・明日へ・逆算チェック）だけを持つ
- サブスクと役割別モデル: `~/Private/personal-os/AIエージェント基盤/AIモデル一覧.md`
- 規模・レビュー・人間ゲート: `~/Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md` §7
- 計画の置き場・状態語彙: `~/Private/personal-os/my-brain/areas/AGENTS.md`
- 入口判断（規模/経路/人間ゲート）: `~/Private/personal-os/AIエージェント基盤/plan-registry/AGENTS.md` ／ モデル・レーン規約: `~/Private/personal-os/AIエージェント基盤/AIモデル一覧.md` ／ 実行中の監督: skill `cockpit-supervisor`

## 朝会モード（発火: おはよう・朝会・朝のルーチン・モーニングルーティン）

1. Claude Code の `/usage`、Codex の `/status` を必要に応じて人間に確認してもらい、結果をモデル一覧と照合する。残量は記録の正本にしない。
2. 前日の実績（終わったこと）は board DB（`../daily-start/scripts/fetch-context.sh` の `yesterday_session_logs`、または focusmap の前日ボード）から読む。前日デイリーmdの「明日へ」と当日デイリーmdの人間記入節も読む。動いているエージェント（現況）は `board.py show` で読み、実態とずれがあれば担当AIが `board.py update`/`log` で直す。
3. **計画確認→選択**（daily-start ①②）: `../daily-start/scripts/fetch-context.sh` の `active_plans` で各active計画の工程進捗（済/全ステップ・次の工程・優先）を把握し、`repo-registry/repo概要.md` と `projects/active/` の実体を突き合わせ（機械確認は `repo-create` の `scripts/repoctl-check.sh`）、人間と「今日進める計画・繰越・動かさないもの」を決める。選んだ意図は **テーマ=意図1行**（任意）で `board.py theme-add --name` に載せる（目的・完了条件は付けない＝正本は計画md）。新しい玉は `kickoff` で依頼インボックスへ1行起票する。
4. **AI割り振り案→承認**（daily-start ③）: 選択計画の「次の工程」を、役割別モデル（`AIモデル一覧.md`）と計画の `並列:` に照らし「どのAIで・並列可か」の割り振り案として提示し、人間の承認を取る。規模・人間ゲートは `~/Private/personal-os/AIエージェント基盤/plan-registry/AGENTS.md` と `GLOBAL_AGENTS.md` §7 に従い、当日の決定はsession-boardにだけ残す。
5. 指揮官が必要なら `references/commander-prompt.md` の可変部を当日の担当に合わせて埋め、チャット出力として渡す。
6. **繰越し・滞留確認**（daily-start ④）と確定起票: 承認後の起票（選択計画の「## 工程」節→`board.py steps` の自動登録・作文ゼロ）は daily-start が担う。テーマ/やることをこの場で作文しない。既存TODO行の削除・書換は人間のみ、`auto:*` 区画には触らない。

## 夜会モード（発火: 夜会・今日の締め・おつかれ）

1. 当日デイリーmdの人間記入節（今日すること・明日へ 等）と、board DB の当日実行ログ（`board.py show`／focusmap の当日「終わったこと」）を読み、全体状況を人間へ短く報告する。
2. 今日のTODOの消し込み・繰越を人間と確認する。AIの更新は追記または `[x]` 化に注記を添え、削除は人間承認後にする。
3. 23:30のみ、`skills/orca-cockpit/scripts/worktree-sweep.sh` を1回実行してクローズ候補/注意を夜会レポートへ載せる。検知だけで、down・削除・反映は人間ゲートに従う。
4. 23:30のみ、「明日へ」の記入を促し、年間/3年目標との接続、放置目標、人間確認待ち、古いactive計画を確認する。新しい作業は依頼インボックスに1行起票する。

## 制約

- 当日の編成・担当・進行中状態をこのSkillや別のロースターに複製しない。デイリー/session-boardが唯一の現在地である。
- 朝会・夜会で発生した新しい作業は、実行前に `kickoff` を通す。
- 起動プロンプトの定型は `references/commander-prompt.md`、実行機構は `orca-cockpit`、監督判断は `cockpit-supervisor` を正とする。

## 吸収元

旧 `my-brain/ゴール/朝夜ルーティン.md` の朝夜手順と逆算確認を吸収済み（2026-07-03）。
