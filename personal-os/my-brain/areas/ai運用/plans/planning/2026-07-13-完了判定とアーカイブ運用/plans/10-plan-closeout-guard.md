親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成
並列: 可 ／ レビュー: 都度
人間ゲート: runtime登録（`~/.claude/settings.json`・`~/.codex/hooks.json`・symlink・Codex再trust）は実装・テスト後に差分を提示して個別承認

# plan-closeout guard

## 目的

計画同期が済んでいないままセッション・サブエージェントが終了する穴を、run manifestを検査するStop／SubagentStopガードで塞ぐ。Hookは意味判断・計画編集をせず、「review_passedなのに未同期」の時だけ終了を継続させる。

## 非対象

- Prompt Submit注入文・session-start/endの計画案内本文（02が所有）
- planctl本体（07。ガードは実行を「要求」するだけで代行しない）
- session-boardの所有境界の変更（セッション記録の所有者のまま）
- runtime登録の実施（人間承認後の別作業単位）

## 現状

Claudeには節目を促すPrompt型Stop Hookがあるが、現行の共有Stop commandはボードを⏸へ変えるだけで計画同期を検査しない。Codex側も同様である。hooks-registryは2026-07-06再編で `events/`（イベント本体）＋`shared/`（共通エンジン）＋`claude/`・`codex/`（登録表）構成になっており、設計資料02 §16が指す旧 `hooks-registry/hooks/plan-closeout/` という置き場はこの再編後構造へ読み替える必要がある（旧 `hooks/` は復活させない）。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/hooks-registry/AGENTS.md`・`events/AGENTS.md`
  2. `hooks-registry/shared/session-board/`（共通エンジンの現行構成・Stop受け口の実装）
  3. `../program.md`・この計画
  4. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §16-17（Stop判定・SubagentStop・session-board更新）
  5. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §14（Hook設計原則）
- 依存成果: 07のrun manifest契約（phase語彙）、08のresult packet schema
- 変更可能範囲: `hooks-registry/shared/plan-closeout/`（新規・ガード本体とテスト）、`hooks-registry/events/` の対応イベント受け口（session-end・subagent系の追加シム）、`hooks-registry/claude/`・`codex/` の登録表（記載のみ・適用は人間ゲート）、`hooks-registry/AGENTS.md` 構成節、session-boardの手順MD（session-end.mdのsync-check案内・milestoneの検知観点）
- 変更禁止範囲: `shared/session-board/common.py` の注入本文（02所有）、`~/.claude/settings.json`・`~/.codex/hooks.json`・symlink実体（人間ゲート）、`skills/plan-ops/`
- 維持する契約: Hookは軽量・決定的・非ブロッキング既定／計画本文・チェックボックス・バケットを編集しない／manifest不在なら必ず通す／session-board Stopと共存
- 検証: fixtureによるruntime別stdout契約テスト＋無限ループ防止テスト
- 停止・エスカレーション条件: Claude/Codex Hookの現行wire formatがローカルversionと公式説明で一致しない／既存session-board Stopとの共存で挙動が壊れる
- 完了時に返す情報: 02指示書§24の完了報告形式（Hook登録状況=未適用を明記）

## 方針

1. ガード本体を `shared/plan-closeout/` に置き、runtime別の薄いシムを `events/` の対応イベントに追加する（旧 `hooks/` 構造は作らない）。`PLAN_RUN_MANIFEST` が設定されている時だけ作用し、無ければ通す。
2. Stop判定: phase=`running/implemented` → 通す（作業途中）。`review_passed` かつ未 `synced` → 継続させ、`planctl apply-evaluation` / `sync-check` の実行を理由として返す。`synced/closed` → 通す。`blocked` → 通すがblockerを結果に残す。Hookは計画を直接編集しない。
3. SubagentStop: role=implementerでresult packet無し → 継続。role=reviewerで必須評価項目無し → 継続。role=explorerは構造化結果があれば通す。
4. 無限ループ防止を必須にする: `stop_hook_active` の考慮、連続block上限、Hook失敗時に既存作業を壊さないfail-open。stdout JSON契約はruntime別にテストする。
5. session-boardの責務ポインタを更新する: `session-end.md` にplanあり完了前の `planctl sync-check` 案内を追加し、Claude milestoneが最終評価とplan syncの不足を検知観点に含むようにする。計画の実行・完了同期の所有はplan-ops/plan-closeoutであることを handbook側（AGENTS）にも1行で示す。
6. 本体・fixture・E2Eを先に実装し、Claude settings・Codex hooks.json・symlink・再trustは差分提示→人間承認後の別作業にする。

## 完了条件（レビュー項目）

- [ ] manifest不在／running／review_passed未同期／synced／blocked の5ケースでStopガードの挙動がfixtureテストで確認でき、review_passed未同期だけが継続を要求する。
- [ ] SubagentStopが implementerのresult packet欠落・reviewerの評価欠落 を検出し、explorerの構造化結果を通す。
- [ ] ガードが計画本文・チェックボックス・バケット・Programマップを一切編集しないことをテストで確認できる（実行前後のファイル不変）。
- [ ] `stop_hook_active`・連続block上限・Hook失敗時fail-openの3種の無限ループ/破壊防止テストがある。
- [ ] Claude/Codex両方のstdout JSON契約テストがあり、既存session-board Stopと同時使用しても双方が機能する。
- [ ] 旧 `hooks-registry/hooks/` を復活させず、`shared/`＋`events/` の責務境界に沿って配置されている。
- [ ] runtime登録・settings変更・symlink・再trustが未適用のまま、適用に必要な差分一覧が提示されている。
- [ ] session-end.mdとmilestoneの更新が、session-boardの所有境界（計画状態を所有しない）を変えていない。
