# 画像スキル簡素化（images-generate のダイエットと責務分離）

- 起票: 2026-07-11（Codex実装担当セッションの派生・人間指示）
- 形: program（独立完了する子計画2本・別repo・並列実行）
- 実行: codex-implementer サブエージェント×2（並列）

## 設計原則（人間が決定）

1. `images-generate` は「Codex組み込み `image_gen` で画像を作ること」だけに特化する。
2. 固有スキル・固有プロジェクトのワークフロー（求人サムネ・Drive・スプシ）には関与しない。固有の手順は呼び出し元（job-create / sns-post）側へ逃がす。
3. プロンプトの出し方・画像生成の一般的方法は workflows/ に置いてよい。
4. キャラクター（ねこみみ/きつね研究員）は既存以前の遺物として**完全削除**（images-generate側・sns-post側とも。人間承認済み 2026-07-11）。
5. 生成の継続・編集（壁打ち）は `codex exec resume <thread_id>` で行う（2026-07-11 実機検証済み: 赤い円→青い円で文脈保持編集を確認）。
6. 英語本文（mockup.md）は日本語化する。

## 子計画マップ

| 子 | 対象repo | 内容 | 状態 |
|---|---|---|---|
| [01-images-generate簡素化](plans/01-images-generate簡素化.md) | private-meta | SKILL.md薄化・日本語化・キャラ削除・sns-post/slide参照更新 | active |
| [02-job-create移設](plans/02-job-create移設.md) | 仕事 | 求人サムネ/prompts.json/CLI/Drive手順を job-create docs へ移設 | active |

## 完了条件（program全体）

- 両子計画のレビュー項目が全部OK。
- `images-generate` から job-create・キャラの記述が消え、SKILL.md が日本語の薄い窓口になっている。
- 仕事repo側で求人サムネ生成手順が自己完結して読める。

## 備考

- 原本スナップショット（ワーカー間の読み書き競合回避用・02はこれを読む）:
  - `/private/tmp/claude-501/-Users-kitamuranaohiro-Private/54420baf-9eac-4afb-9cb1-9702f9737218/scratchpad/general-image-original-snapshot.md`
- images-generate / sns-post / slide は現在git未追跡（07-08移行後未コミット）。触ったファイルだけ明示パスでadd。
