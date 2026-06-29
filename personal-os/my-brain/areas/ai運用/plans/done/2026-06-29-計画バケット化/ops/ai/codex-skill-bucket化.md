# Codex実行指示: Skillルーティングのバケット方式化

種別: ai
状態: done
日付: 2026-06-29 JST
親計画: ../../plan.md

## このファイルの位置づけ

別エージェント（Codex想定）が、チャットの文脈なしで実行できる手順書。
作業前に必ず読む正本:
- `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`（Skill正本編集の運用ルール）
- `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/AGENTS.md`（Plan標準構成＝バケット規約）
- `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/AGENTS.md`（計画ルーティング）

## ゴール

Skill等のルーティング記述を、計画の「フィールド方式」から「バケット方式」へ統一する。
- バケット方式 = 計画は `ai運用/plans/active/<name>/plan.md` に作り、状態は
  `active/paused/done/archive` フォルダで持つ。plan.md に `状態:` フィールドは書かない。
- `分類:`（skill/repo/loop）と `種別:`（新規作成/既存改善/統合整理）は plan.md 冒頭に書く（維持）。

## 前提（重要・スコープ限定）

1. 変更するのは **Global / Personal OS側（ai運用/plans/…）の記述だけ**。
2. **repo-local 側（所有repo内 `plans/skills/<種別>/<状態>/`）の記述は変更しない**。
   この repo-local は今も状態フォルダ方式のまま。混在は意図的。
3. 履歴ログ（registry の logs配下）は事実の記録なので変更しない。

## 対象ファイル（Global側の計画パス・状態記述を含む）

- AIエージェント基盤/README.md
- AIエージェント基盤/AGENTS.md
- AIエージェント基盤/global-skill-registry/AGENTS.md
- AIエージェント基盤/repo-registry/AGENTS.md
- AIエージェント基盤/skills/skill-creator-custom/SKILL.md
- AIエージェント基盤/skills/skill-creator-custom/references/create-rules.md
- AIエージェント基盤/skills/skill-creator-custom/references/review-rules.md
- AIエージェント基盤/skills/skill-creator-custom/references/absorb-rules.md
- AIエージェント基盤/skills/skill-creator-custom/workflows/review-skill.md
- AIエージェント基盤/skills/skill-creator-custom/workflows/create-new.md
- AIエージェント基盤/skills/skill-creator-codex/SKILL.md

まず現状を洗う:
```
grep -rn "ai運用/plans\|状態: \|状態:を書く\|状態: planning\|状態: ready\|状態: active" \
  /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤 | grep -v "/logs/"
```

## 書き換えルール（各箇所を読んで判断して適用。blind sed 禁止）

1. 新規計画の作成先パス: `ai運用/plans/<YYYY-MM-対象>/plan.md`
   → `ai運用/plans/active/<YYYY-MM-対象>/plan.md`（`active/` を補う）。
2. 「plan.md に `状態:` を書く」「`状態: planning`/`ready`/`active` を書く・更新する」等の
   フィールド前提の指示（Global側）→ バケット方式に置換:
   - 新規は `active/` に作る。
   - 作業完了（未評価）は plan.md に結果を追記して `done/` へ `git mv`。
   - 評価OKで `archive/` へ。問題あれば `active/` へ戻す。
   - 「状態はバケットで持つ。`状態:` フィールドは書かない」と明記。
3. `分類:`・`種別:` を書く指示は維持する。
4. 状態・バケットの定義参照は `my-brain/areas/AGENTS.md`、計画ルーティングは
   `ai運用/AGENTS.md` を指すようにする。
5. repo-local 側（`所有repo内 plans/skills/<種別>/<状態>/`）の記述はそのまま残す。

## 検証

```
grep -rn "ai運用/plans/<\|ai運用/plans/[0-9]" \
  /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤 | grep -v "active/" | grep -v "/logs/"
```
→ Global新規計画パスで `active/` が抜けている箇所が無いこと。

```
grep -rn "状態: planning\|状態: ready\|状態: active\|`状態:` を書く" \
  /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤 | grep -v "/logs/"
```
→ Global側にフィールド状態前提の指示が残っていないこと（repo-local文脈の行だけなら可。要目視）。

## 完了条件

1. Global新規計画パスが全て `ai運用/plans/active/<name>/`。
2. Global側にフィールド状態（`状態:`）前提の作成・更新指示が残っていない。
3. repo-local 側の記述は不変。
4. 親計画 `../../plan.md` の完了条件を満たす。

## Git
`AIエージェント基盤/AGENTS.md` のGit運用に従う。意味のある単位でcommit。push/main操作はしない。
完了後、親計画 `2026-06-29-計画バケット化` を `done/` へ `git mv`（評価後に `archive/`）。
