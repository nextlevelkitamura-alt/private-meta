# 計画ライフサイクル: plans直下バケット設計

状態: 一部適用済み（構造）。残りはレビュー完了後。
日付: 2026-06-29 JST

## 進捗

- [x] 構造: 全area（work, ai運用, money, health）の plans/ に active/paused/done/archive（+.gitkeep）作成。
- [x] 構造: areas/AGENTS.md Plan標準構成、ai運用/AGENTS.md 計画ルーティングをバケット方式に更新。
- [x] 振り分け: active←orca/career、done←done7件（基盤整理含む）へ git mv。
- [x] strip: 全plan.md から `状態:` フィールド除去（`分類:`/`種別:` は維持）。
- [x] 参照修正: 基盤整理 を指す2箇所を done/ パスへ更新。
- [x] skill handoff 作成: `plans/active/2026-06-計画バケット化/ops/ai/codex-skill-bucket化.md`（状態 ready）。
- [ ] skill実行: 約12ファイルの「フィールド方式→バケット方式」化（Codexへ委譲、上記handoff）。

レビュー完了報告を受けて 2026-06-29 に実施。skill側の実行のみ Codex 残。

## 決定

1. 各 area の `plans/` 直下にライフサイクルバケットを置く: `active / paused / done / archive`。
2. **フォルダが計画の状態の正本**。plan.md の `状態:` フィールドは廃止する。
   - 残すフィールド: `種別:`（新規作成/既存改善/統合整理）、`分類:`（skill/repo/loop）。これらは分類であり状態ではない。
3. バケットの意味:
   - `active`: 進行中、または着手前で今のスコープに入っているもの。
   - `paused`: 一時停止。再開予定あり。
   - `done`: エージェントが作業完了。**まだ評価していない**。
   - `archive`: 評価して問題なしを確認済み。参照専用に格納。
4. ops階層は変更しない。`ops/<種別>/<作業名>.md` の状態はファイル内 `状態:` 行のまま。
   理由: plansはarea全体で溜まるのでフォルダ分けが効く。ops は1計画内で少数・短命なのでファイル内で十分。スケールが違う。

## 構造

```text
areas/<area>/plans/
  active/   <YYYY-MM-name>/plan.md
  paused/   .gitkeep
  done/     .gitkeep
  archive/  .gitkeep
```

## 移動方法（AGENTS.md に明記する）

- 新規計画は `plans/active/<YYYY-MM-short-name>/plan.md` に作る。
- 一時停止: `git mv plans/active/<name> plans/paused/<name>`。
- 作業完了（未評価）: plan.md に結果を追記し、`git mv` で `done/` へ。
- 評価OK: `git mv` で `archive/` へ。問題あれば `active/` へ戻す。
- 空の paused/done/archive は `.gitkeep` を置く（git は空ディレクトリを保存しないため）。

## レビューフローとの対応

Codex 等のエージェントが完了報告 → 該当計画は `done/`。
人間の完了報告を受けた Claude が評価 → 問題なければ `archive/`、要修正なら `active/` へ戻す。
この遷移がそのままレビューゲートになる。

## 適用時にやること（Codex完走後・Claudeが実施）

1. 全area（work, ai運用, money, health）の `plans/` に `active/paused/done/archive`（+.gitkeep）を作る。
2. 既存計画をバケットへ振り分け（`git mv`）:
   - work: career-transition → active/
   - ai運用: 基盤整理 → active/、orca-cli → active/、移行された done 計画群 → done/（評価後に archive/）
3. `areas/AGENTS.md` の Plan標準構成にバケットと移動方法を追記。plan.md の `状態:` 廃止を明記。
4. skillルーティングの新規計画作成先を `ai運用/plans/active/<name>/` に更新（Codexが書いた約12ファイルのパスに `active/` を補う）。
5. 上位AGENTS.md（personal-os, Private, my-brain）の新規計画パス記述も `plans/active/` に合わせる。

## 注意

plan.md の `状態:` 廃止は、Codex が移行時に `状態:` フィールドを付ける手順と衝突する。
適用時に、移行済み plan.md から `状態:` を外し、バケット配置に読み替える（情報は失わない）。
