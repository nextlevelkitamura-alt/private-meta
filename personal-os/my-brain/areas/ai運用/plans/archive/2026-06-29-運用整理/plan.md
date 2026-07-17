分類: repo
種別: 既存改善

# 運用整理

## 目的

my-brain/areas 全体を俯瞰し、使いやすくするために、足りないルール・文書・命名を1本化する。
点在していた運用ルールを `areas/AGENTS.md` に集約し、欠けていた命名規約と2-repo git構造を明文化する。

## 決定（この会話で確定）

1. plan フォルダ命名 = `YYYY-MM-DD-日本語企画名`。
   - 日付は作成日。固有名詞（Orca, skill-creator-custom 等）は識別子として残す。
   - 企画名は日本語で簡潔に（15〜20字目安）。
2. 並行エージェントは停止し、my-brain ツリーは単一エージェントで触る（衝突防止）。

## ギャップと対応

- [x] P1 命名規約を `areas/AGENTS.md` Plan標準構成に明記（`<YYYY-MM-short-name>` → `<YYYY-MM-DD-日本語企画名>`）。
- [x] P1 2-repo git構造を `personal-os/AGENTS.md` に常設明文化
      （Private=ローカルのみ／AIエージェント基盤=別repo・別remote・gitignore）。
- [x] P2 done→archive の評価ゲート（誰が・いつ）を `areas/AGENTS.md` に一文追加。
- [x] P2 既存plan を新命名へリネーム＋参照更新（全11件・参照grep 0確認済み）。
- [x] P2 Skill側のフィールド→バケット方式化（Codex実施・AIエージェント基盤repoコミット済 2026-06-29）。
- [ ] P3（保留）area をまたぐ core（価値観・人生方針）の置き場。必要になってから。
- [ ] P3 money/health は空のまま（計画が出てから、で可）。

## 命名リネーム案（要・人間確認）

active:
- work `2026-06-career-transition` → `2026-06-29-キャリア転換`
- ai運用 `2026-06-commit整理` → `2026-06-29-2repoコミット整理`
- ai運用 `2026-06-orca-cli-multi-agent-workflow` → `2026-06-29-OrcaCLI複数エージェント運用`
- ai運用 `2026-06-計画バケット化` → `2026-06-29-計画バケット化`

archive（作成日に合わせる）:
- `2026-06-基盤整理` → `2026-06-29-plans廃止とarea一本化`
- `2026-06-repo-relocation` → `2026-06-28-repo移動Skill新規`
- `2026-06-repo-create-agents-md-governance` → `2026-06-29-repo-create統合整理`
- `2026-06-skill-creator-custom-命名ルール` → `2026-06-27-skill-creator命名ルール改善`
- `2026-06-skill-creator-custom-種別ルーティング` → `2026-06-27-skill-creator種別ルーティング改善`
- `2026-06-skill-creator-custom-計画書構造` → `2026-06-27-skill-creator計画書構造改善`
- `2026-06-基盤-機能説明更新` → `2026-06-27-基盤機能説明更新`

リネーム時の注意:
- 参照あり = `基盤整理`（my-brain/AGENTS.md, ai運用/AGENTS.md が archive パスを指す）。
- `2026-06-計画バケット化` は `2026-06-commit整理` が相対参照。
- リネーム後、各参照を grep で洗って更新する。

## 完了条件

1. `areas/AGENTS.md` に命名規約と評価ゲートが書かれている。
2. `personal-os/AGENTS.md` に2-repo git構造が書かれている。
3. 既存plan が新命名で、壊れた参照が無い（grep 0）。
4. 運用ルールが `areas/AGENTS.md` に1本化され、thinking/AGENTS間で重複していない。

## 関連

- バケット設計: `../../../thinking/plans-lifecycle.md`
- Skill書き換え: `../2026-06-29-計画バケット化/ops/ai/codex-skill-bucket化.md`
- コミット: `../2026-06-29-2repoコミット整理/ops/ai/codex-commit整理.md`
