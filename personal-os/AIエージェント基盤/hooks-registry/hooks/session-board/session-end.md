# session-end — 完了報告・git仕上げ（節目でのみ）

この手順は、Stop の **prompt型フック（milestone.md 判定）が「大目標が達成されユーザーが満足した気配」と
判断した節目でのみ**注入される（毎ターンではない・2026-07-05）。
状態の⏸への機械flipは claude/session-end.py が毎ターン行う（この手順とは独立）。

`<board>` = `~/Private/personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/board.py`。

## 1. 完了判断

- このセッションの大目標が一通り達成されたかを、会話＋**git実体（`git status`／`git log`）の二重チェック**で判断。

## 2-A. 達成 → 人間に1回だけ確認

成果の箇条書き案を添えて確認する:

> この依頼は完了と判断しました。次を実行してよいですか？
> ① 「終わったこと」へ記載（親＝タスク／子＝時刻付き成果の入れ子）
> ② 未コミット分のコミット（このセッションで触ったファイルのみ・パス指定）
> ③ ブランチが main 以外なら main へマージ → push（main上なら push のみ）
> ④ まだ終わっていない（このまま続ける）
> ※ ②③が不要なら「①だけ」、続行なら「④」と返してください

**人間OK →**

- **計画種別のセッションは finish 前に** `plan-ops` の `program-lint.sh <program.md>` を1回流す（program計画のみ・違反があれば直してから締める）。

1. `<board> finish --key <キー> --repo <repo> --parent <目標名> --entry <成果1行>`（`--entry` は数だけ繰り返し・親名=行の目標名にする）。
   自行がボードから消え、成果が「終わったこと」の該当repo見出しに **親＋時刻・所要(+Nm)付き子** で入る
   （途中で `log` 済みの子があれば、finish は同じ親にさらに子を足す・親は重複しない。時刻・所要は自動付与）。
2. git仕上げ（**②③を含む場合のみ**）: このセッションで変更したファイルを **パス指定で add→commit**
   （**`git add -A` 禁止**）。main以外なら main へマージ→push。
   **中断条件**: コンフリクト／repoポリシー（main直pushブロック・PR運用）／detached HEAD → 止めて報告。
   **禁止**: force push・履歴改変・ブランチ削除。repo-local AGENTS.md のgit運用が優先。
3. 大きな作業の締めは完了レポートHTML（`/html`）。小さな作業は省略可。

## 2-B. 未達（④・素通し）

- 残作業を `<board> update --now`（目的が変われば `--goal`）で書き換えて続行（⏸への遷移は session-end.py が保証。ただし🔵サブ稼働中は維持され⏸にしない）。

## してはいけないこと

- 完了確認を経ずに行を消す／完了時刻を推測で書く（**finish/log の自動付与が正**）／`git add -A`／
  force push／確認なしのマージ・push／secret混入。
