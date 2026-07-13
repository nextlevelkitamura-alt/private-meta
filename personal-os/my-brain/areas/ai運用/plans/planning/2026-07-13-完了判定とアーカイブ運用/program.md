分類: 横断 ／ 種別: 既存改善 ／ 形態: program ／ 規模: フル

# 完了判定とアーカイブ運用

## 目的

計画の状態遷移を、人間が一目で追える次の一本道に統一する。

```text
planning → active → done → archive
             │        │        └ 人間が明示確認した後だけ
             │        └ 実装済み・最終レビュー全PASS
             └ 今週実行中
```

`done` は「実装とAIレビューが終わったが、人間確認を待つ」状態、`archive` は「人間が確認し、参照専用にした」状態とする。セッションを終える `session-board finish` と、計画を archive へ動かす行為を同一視しない。

容量は各 `plans/` 直下ごとに `planning=上限なし / active=3 / paused=3 / done=8 / archive=上限なし` とする。上限は移動先へ入る直前に判定し、満杯ならAIが別計画を勝手に paused・done・archive へ移して枠を作ることはしない。

## 全体像

現行規約は `done=未評価`／`archive=評価済みOK` と書いている一方、Prompt Submit の注入は「評価全PASS=done」とだけ伝え、session-end は人間確認後のセッション終了を案内する。さらに実際に archive 化された program に未完了の子マップが残り得るため、状態名・機械手続き・注入文・既存データの4層が揃っていない。

まず01で状態の意味・各バケットの上限・遷移ガードを決め、`active→done` を最終評価で機械的に確認できる操作にする。次に02と04を並列で進め、Prompt Submit の案内と、Codex/Claude が生の `git mv` で計画バケットを迂回できないPreToolガードを整える。最後に03で既存の active/done/archive を監査し、上限超過の是正候補を人間承認付きで扱う。既存計画をこのprogramの実装だけで勝手に動かさない。

人間確認は技術的な認証ではない。CLIのフラグだけで「人間だった」とは証明できないため、**実際の明示発言を前提に、確認日時・短い確認内容を計画本文へ記録してから archive 操作を許す**運用ガードにする。曖昧な肯定、session-board の `finish`、AI自身の完了判断は archive 承認に数えない。

現時点のai運用は paused=24、done=18であり、新しい上限（各3／8）をすでに超えている。よって導入直後は `bucketctl check` とPreToolガードが**超過を可視化し、新規流入だけを拒否**する。超過を解消する移動は03で候補を出し、人間が対象ごとに決めるまで自動では行わない。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01  完了判定と遷移統制 … 計画
    並列: 不可 ／ レビュー: 都度(規約・CLI・テストの同時照合)
    次: `done`/`archive` の意味、各バケット上限、`bucketctl` の遷移・容量ガード、結果・人間確認の記録先を設計して実装する
    場所: plans/01 ／ 依存: ―
- [ ] 02  Prompt Submit計画注入の再設計 … 計画
    並列: 可 ／ レビュー: 都度(common.py と runtime双方の注入テスト)
    次: 01の遷移・容量契約に合わせ、Prompt Submit・session-start/end・README・milestone の計画案内を最小化して統一する
    場所: plans/02 ／ 依存: 01
- [ ] 03  既存計画の整合監査と上限是正 … 計画
    並列: 不可 ／ レビュー: 都度(一覧と移動候補を独立照合)
    次: 全バケットを監査し、状態矛盾と上限超過の移動候補を提示する。実際の移動は人間の個別承認後に行う
    場所: plans/03 ／ 依存: 01, 02, 04
- [ ] 04  上限超過の警告とAIガード … 計画
    並列: 可 ／ レビュー: 都度(Codex/ClaudeのPreTool出力と拒否経路を別々に検証)
    次: 生のバケット移動を止めるPreToolガード、超過警告、AGENTS/Skill導線を共通契約へ統一する
    場所: plans/04 ／ 依存: 01

## 完了条件（レビュー項目）

- [ ] `active → done` が「実装済みかつ最終評価mdが全PASS」でのみ進み、`done → archive` は人間の明示確認の記録がある時だけ進むことを、規約・CLIテストで確認できる。
- [ ] 各 `plans/` root で `active≤3`、`paused≤3`、`done≤8` を移動先ごとに強制し、`planning` と `archive` は上限なしである。超過済みの既存バケットは可視化・流入拒否するが、自動退避しない。
- [ ] `areas/AGENTS.md`、`運用契約.md`、plan-ops のテンプレ／SKILL／tests が同じ状態語彙と責務を示し、`状態:` の二重管理を増やしていない。
- [ ] UserPromptSubmit の初回ガイドとミラーが、planning 起案・active 実行・done 待機・archive 人間確認・バケット上限という契約を、過剰な本文複製なしに案内する。
- [ ] Codex/ClaudeのPreToolガードが、計画バケットへの生の `git mv` / `mv` を拒否して `bucketctl` へ誘導する。新規hookのruntime登録・Codex再trustは実装直前に人間確認を得てから行う。
- [ ] 上限到達時は件数・上限・対象一覧・次に必要な人間判断を警告するが、AIが勝手に paused/done/archive を選ばない。
- [ ] session-board の `finish` はセッション記録を閉じる操作であり、明示した計画 archive 承認なしに計画を動かさないことがテストと手順MDで明確である。
- [ ] 既存の active/paused/done/archive の監査結果と、状態矛盾・上限超過ごとの人間承認待ち移行候補一覧があり、承認なしの一括移動・削除をしていない。
- [ ] 変更対象の plan-ops と session-board のテスト、および program-lint が通り、決定ログに1件の採用判断がある。

## 関連

- 状態・計画規約: `../../../../AGENTS.md` §3-4 ／ `../../../../../../説明書/運用契約.md` §2
- 計画操作: `../../../../../../AIエージェント基盤/skills/plan-ops/`
- Prompt Submit 本体: `../../../../../../AIエージェント基盤/hooks-registry/hooks/session-board/common.py`
- セッション手順: `../../../../../../AIエージェント基盤/hooks-registry/hooks/session-board/{session-start,session-end}.md`
