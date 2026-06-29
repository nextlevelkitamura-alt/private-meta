# 基盤整理

分類: repo
種別: 統合整理
日付: 2026-06-29 11:52 JST
完了: 2026-06-29 JST

## 目的

personal-os の計画を領域別（`my-brain/areas/`）に一本化し、旧 `personal-os/plans/` を廃止する。
あわせて ops の状態管理をフォルダからファイル内表記へ統一する。

## 背景

1. 旧 `personal-os/plans/` は領域で分かれておらず、何の計画か分からなくなるデメリットがあった。
2. area単位（work, ai運用 など）に分ければ「どの領域の話か」が常に分かる。
3. 考えた内容がチャットで流れて消える問題があり、決定を計画として書き留める必要がある。

## 決定事項（この会話で確定）

1. ops の状態はフォルダで分けない。計画作成時に作るのは種別5フォルダ（`.gitkeep`付き）のみ。
   状態（planning/active/done 等）は各作業ファイルの `状態:` 行で持つ。
   - 反映先: `my-brain/areas/AGENTS.md`, `areas/work/AGENTS.md`, `personal-os/AGENTS.md`, work計画の plan.md。
   - 実体: career-transition の ops を種別5フォルダへ作り直し済み。
   - コミットは別エージェントに委譲（独立コミット）。
2. 計画の単一正本は `my-brain/areas/<area>/plans/<計画名>/plan.md`。`personal-os/plans/` は廃止する。
3. 基盤（personal-os自体、Skill、repo、loop、CLI＝Orca等）はこの「ai運用」areaが担当する。
   - area名は `ai運用`。実装正本 `personal-os/AIエージェント基盤/` とは役割が別（考え・計画 vs 実装）。

## 現状調査（2026-06-29 時点）

1. `personal-os/plans/` の実体ファイルは7件のみ。大半が done。生きた計画は1件
   （`plans/skills/新規作成/planning/2026-06-29-orca-cli-multi-agent-workflow新規作成.md`）。
2. 残りは空 `.gitkeep` スケルトン（種別×状態を先回り作成したもの）。
3. `plans/` パスを参照する箇所は当初想定の「7ファイル」ではなく、約12ファイル・40箇所以上。
   - `AIエージェント基盤/AGENTS.md`（9）, `README.md`（3）
   - `global-skill-registry/AGENTS.md`（3）, `repo-registry/AGENTS.md`（4）
   - `skill-creator-custom`（SKILL.md + references3 + workflows2 に多数）, `skill-creator-codex/SKILL.md`
   - `repo-registry/logs/.../06-28-ai-agent-foundation.md`（履歴。書き換え不要、残す）
4. 状態フォルダの廃止は repo-local 側にも波及する。skill-creator-custom は Global と
   repo-local（所有repo内 `plans/skills/<種別>/<状態>/`）の両方で `<種別>/<状態>/` を使う。
5. `plans/AGENTS.md`（97行）は完成した計画ルーティング規約。廃止＝この規約を ai運用 へ移し替え、
   Global/repo-local の計画配置ルール全体を再設計する作業になる。

## 設計判断（確定）

1. 置き方は area規約に統一する。1計画=`plans/<計画名>/plan.md`、種別・状態・分類は plan.md 冒頭フィールドで持つ。
2. repo-local 側（所有repo内 `plans/skills/<種別>/<状態>/`）は今回いじらない。廃止対象は `personal-os/plans/` のみ。

## 実行は Codex へ委譲

詳細手順は `ops/ai/codex-plans廃止移行.md`（種別: ai / 状態: ready）に切り出した。
別エージェント（Codex想定）がこのチャットの文脈なしで実行できる手順書。
トークン見積もり: 10万〜25万、慎重め手戻り込みで最大30万程度。

移行の大枠:
- [x] 旧 `plans/AGENTS.md` 規約を ai運用/AGENTS.md へ移し替え（状態フォルダ記述は持ち込まない）。
- [x] 実計画7件を ai運用/plans/ へ移す（種別/状態/分類フィールドを補う）。
- [x] 約12ファイルの Personal OS側 `plans/` 参照を新パス・新規約へ書き換え（repo-local記述は維持）。
- [x] 上位AGENTS.md（personal-os, Private, my-brain, areas）の記述を更新。
- [x] grep検証 → 履歴ログ以外にヒットが残らないこと。
- [x] 旧 `personal-os/plans/` 削除（2026-06-29 人間承認済み、削除・再検証完了）。

## 結果（2026-06-29）

Codex が Step1〜5 を実行し、Claude が削除前レビュー6項目を全パス確認。人間承認後に削除・再検証まで完了。
- 実計画7件は `ai運用/plans/` へ移行（`分類/種別/状態` フィールド付き、本文保持）。
- 旧 `plans/AGENTS.md` 規約は `ai運用/AGENTS.md` の「計画ルーティング」へ集約。
- 約12ファイルの Personal OS側 `plans/` 参照を ai運用 へ書き換え。repo-local 規約は不変。
- 上位4 AGENTS.md 整合、`personal-os/plans/` 削除済み。参照grepヒット0。
- 未コミット（コミットは別エージェントに委譲）。

## 進め方メモ

ai運用 area は完成済みなので、新しい基盤計画（Orca CLI 等）は移行を待たず先行してここで回せる。

## 削除前レビュー（Codex完了報告後に Claude が実施）

Codex が Step1〜5 を終えたら、人間から完了報告を受けた Claude が以下を確認し、
全て満たした時だけ「plans/ 削除OK」と判定する。1つでも欠ければ削除しない。

1. 参照クリーン: 下記 grep が履歴ログ以外でヒット0。
   ```
   grep -rn "personal-os/plans\|plans/skills/global\|plans/repositories\|plans/loops" \
     /Users/kitamuranaohiro/Private/personal-os /Users/kitamuranaohiro/Private/AGENTS.md \
     | grep -v "my-brain/areas" | grep -v "logs/"
   ```
2. 実計画移行: 旧 plans/ の実ファイル7件が ai運用/plans/ に存在し、`分類:` `種別:` `状態:` を持つ。
   内容が欠落・改変されていない（特に生きてる orca-cli）。
3. 規約移行: 旧 plans/AGENTS.md の実質ルールが ai運用/AGENTS.md にあり、重複や状態フォルダ記述が無い。
4. repo-local 不変: 所有repo内 `plans/skills/<種別>/<状態>/` の記述が変更されていない。
5. 上位整合: personal-os/AGENTS.md, Private/AGENTS.md, my-brain/AGENTS.md, areas/AGENTS.md が
   現状（plans/廃止）と一致している。
6. plans/ 残存物: `personal-os/plans/` に残っているのは空 .gitkeep スケルトンと AGENTS.md のみで、
   未移行の実計画が無い。

判定後の削除は人間の明示承認を得てから実行する（AIエージェント基盤 AGENTS.md 9章）。
削除後の評価・追加改善は Claude に一任（ユーザー合意済み 2026-06-29）。

## Ops

作業が出たら `ops/<種別>/<作業名>.md` に置き、状態はファイル内の `状態:` 行で持つ。
種別・状態の定義は `../../AGENTS.md` を参照する。

## 完了条件

1. 計画の置き場が `my-brain/areas/<area>/plans/` に一本化されている。
2. `personal-os/plans/` が存在しない。
3. Skillの `plans/` 参照が全て新パスへ更新され、ルーティングが壊れていない。
4. 関連AGENTS.mdの記述が現状と一致している。

## 関連thinking

未記入。
