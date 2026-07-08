分類: 横断 ／ 種別: 既存改善 ／ 形態: program
優先: ◎

# 計画実行フロー統一

## 目的

全作業repoの「計画の置き場」と「セッションの宣言・記録」を1つの型に統一する。
人間が当日デイリーのボードと各repoの `plans/` だけを見れば、いま誰（どのruntime/モデル）が・どの目的で・何をしていて・何が終わったかが分かる状態にする。

## 全体像

- 傘（このprogram）: 計画実行フロー統一。
- 子01: session-board機構の責務再設計。境界は「Python=枠と機械処理（速く確実に・記録を落とさない）／AI=意味づけ（種別・目標・今・置き場の判断）」。2列ボード（目標/今）・種別5種・目的別ビュー・生存照合の誤爆修正・保険loopまで。
- 子02: 計画置き場の全リポ統一。`<repo>/plans/planning|active|paused|done/` 決め打ち（GLOBAL_AGENTS.md §6 の実体化）。代表2リポ（focusmap・仕事）のlegacy計画を棚卸して移行する。
- 依存方向: 子01が注入する「計画チェーン」（repo概要.md→所属repo→`<repo>/plans/`）が機能する前提として、子02で各repoの `plans/` が実体化される。子01は子02を待たずに実装できる（チェーン自体は既存規約 GLOBAL_AGENTS.md §6 を指すだけ）。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

01  session-board責務再設計 … active
    次: 実装・テスト完了 → 実運用で観察（launchctl load と Codex 再trust は人間ゲート）
    場所: plans/01-session-board責務再設計.md ／ 依存: ―
02  計画置き場の全リポ統一 … planning
    次: focusmap・仕事のlegacy計画の棚卸し → 移行一覧を作り人間承認 → 移動実行
    場所: plans/02-計画置き場の全リポ統一.md ／ 依存: 01

## 完了条件（レビュー項目）

- [ ] 子01のレビュー項目が全て満たされている（plans/01-session-board責務再設計.md）
- [ ] 子02のレビュー項目が全て満たされている（plans/02-計画置き場の全リポ統一.md）
- [ ] session-board README・受け口AGENTS.md の記述が実装と一致している（二重管理・記述ドリフトなし）

## 関連

- 機構正本: `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/`
- 計画規約: GLOBAL_AGENTS.md §6（`<repo>/plans/` 決め打ち）／ `my-brain/areas/AGENTS.md` §3-§5（バケット語彙・卒業）
- repo一覧の起点: `personal-os/AIエージェント基盤/repo-registry/repo概要.md`
- 設計経緯: 2026-07-07〜08 の対話（理解確認①〜⑤のHTML・7指摘の反映はこのセッション）
