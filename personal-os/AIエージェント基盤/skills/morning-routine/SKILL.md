---
name: morning-routine
description: 朝会と夜会の定型手順。朝会=usage確認→前日/当日デイリーとactive計画の確認→人間との優先順位・実行形の決定→起動プロンプト生成→当日TODO更新。夜会=当日デイリーを基に状況報告・TODO消し込み・明日への引継ぎと逆算確認。Use when ユーザーが「おはよう」「朝会」「朝のルーチン」「モーニングルーティン」「朝会して」と言った時（朝会モード）、または「夜会」「今日の締め」「おつかれ」「締めて」と言った時（夜会モード）。
---

# morning-routine（朝会と夜会）

1日の始まりと締めの定型。状態・担当・モデルの本文は持たず、既存の正本を読む順と手順だけを持つ（scriptなし）。

正本ポインタ（本文に複製しない）:

- 当日の状態・担当・実行ログ: 当日デイリー（`my-brain/ゴール/デイリー/<年>/<月>/<日>.md`）と session-board
- サブスクと役割別モデル: `~/Private/personal-os/AIエージェント基盤/AIモデル一覧.md`
- 規模・レビュー・人間ゲート: `~/Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md` §7
- 計画の置き場・状態語彙: `~/Private/personal-os/my-brain/areas/AGENTS.md`
- 入口判断（規模/経路/起動形/モデル）: skill `plan-triage` ／ 実行中の監督: skill `cockpit-supervisor`

## 朝会モード（発火: おはよう・朝会・朝のルーチン・モーニングルーティン）

1. Claude Code の `/usage`、Codex の `/status` を必要に応じて人間に確認してもらい、結果をモデル一覧と照合する。残量は記録の正本にしない。
2. 前日デイリーの「今日のダイジェスト」「今日終わったこと」「明日へ」と、当日デイリーを読む。session-boardの動作中行とずれがあれば、担当AIが board update/log で直す。
3. active計画、`repo-registry/repo概要.md`、`projects/active/` の実体を突き合わせ（突き合わせは `repo-create` の `scripts/repoctl-check.sh` で機械確認する）、人間と「繰越・今日やること・動かさないもの」を決める。新しい玉は `kickoff` で依頼インボックスへ1行起票する。
4. レーン数・担当・起動形・モデルを決める。規模と人間ゲートは `plan-triage` と `GLOBAL_AGENTS.md` §7 に従い、当日の決定はデイリーとsession-boardにだけ残す。
5. 指揮官が必要なら `references/commander-prompt.md` の可変部を当日の担当に合わせて埋め、チャット出力として渡す。
6. 朝会結論を当日のTODOへ追記する。既存行の削除・書換は人間のみ、`auto:*` 区画には触らない。

## 夜会モード（発火: 夜会・今日の締め・おつかれ）

1. 当日デイリーの「今日のダイジェスト」とsession-boardの実行ログを読み、全体状況を人間へ短く報告する。
2. 今日のTODOの消し込み・繰越を人間と確認する。AIの更新は追記または `[x]` 化に注記を添え、削除は人間承認後にする。
3. 23:30のみ、`skills/orca-cockpit/scripts/worktree-sweep.sh` を1回実行してクローズ候補/注意を夜会レポートへ載せる。検知だけで、down・削除・反映は人間ゲートに従う。
4. 23:30のみ、「明日へ」の記入を促し、年間/3年目標との接続、放置目標、人間確認待ち、古いactive計画を確認する。新しい作業は依頼インボックスに1行起票する。

## 制約

- 当日の編成・担当・進行中状態をこのSkillや別のロースターに複製しない。デイリー/session-boardが唯一の現在地である。
- 朝会・夜会で発生した新しい作業は、実行前に `kickoff` を通す。
- 起動プロンプトの定型は `references/commander-prompt.md`、実行機構は `orca-cockpit`、監督判断は `cockpit-supervisor` を正とする。

## 吸収元

旧 `my-brain/ゴール/朝夜ルーティン.md` の朝夜手順と逆算確認を吸収済み（2026-07-03）。
