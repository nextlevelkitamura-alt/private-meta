# 02: 求人サムネ生成手順の job-create 移設（仕事repo）

親: [program.md](../program.md)。対象repoは `/Users/kitamuranaohiro/Private/projects/active/仕事`（独立git repo）。作業前に同repoの `AGENTS.md` を読むこと。

## 入力（原本スナップショット）

`/private/tmp/claude-501/-Users-kitamuranaohiro-Private/54420baf-9eac-4afb-9cb1-9702f9737218/scratchpad/general-image-original-snapshot.md`
（= 簡素化前の images-generate/workflows/general-image.md 全文。並列で書き換わるため必ずこのスナップショットから抽出する）

## やること

### 1. `scripts/job-create/docs/image-generation.md` を新規作成

スナップショットから以下を抽出・移設し、job-create 視点で自己完結する手順書に再構成する（日本語）:
- 求人サムネの原則（テキストなし・ロゴなし・ブランド名なしの実写風、image_gen 優先）。
- prompts.json の形式（jobId/jobName/prompt）と置き場 `scripts/job-create/data/prompts.json`。
- 生成画像のコピー先 `scripts/job-create/output/images/generated/{jobId}.png`。
- フォールバックCLI一式（ChatGPT/Gemini・参照画像・リジューム・オプション一覧表・副作用・Drive アップロード・認証切れ対処）。
- 冒頭に1行: 「汎用の画像生成・プロンプト作法はグローバル `images-generate` スキルに従う。ここは job-create 固有の入出力とフォールバックだけを扱う」。

### 2. 仕事repo内の参照更新

- `rg -l "general-image|images-generate" を仕事repo内（.claude/skills/・docs/・scripts/job-create/）で実行し、求人サムネの生成手順として general-image.md の該当節を参照している箇所があれば、新設 `scripts/job-create/docs/image-generation.md` への参照に差し替える（最小修正）。
- 該当が無ければ何もしない（無理に導線を増やさない）。

## 制約

- 仕事repoの既存未コミット変更に触らない。作成・変更したファイルだけを明示パスで `git add`。
- push しない。コミットは日本語1行＋`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`。
- images-generate 側（private-meta）には一切触らない（01 の担当）。

## レビュー項目（こうなっていれば正しい）

1. `scripts/job-create/docs/image-generation.md` が存在し、prompts.json 形式・出力パス・CLIオプション表・Drive/認証の記述がスナップショットから漏れなく移っている。
2. 同ファイルだけで求人サムネ生成の手順が完結して読める（images-generate の旧節を前提にしない）。
3. 仕事repo内に general-image.md の削除予定節（prompts.json/CLI/Drive）へのポインタが残っていない。
4. コミットが明示パスaddのみで、仕事repoの無関係な未コミット変更が混入していない。
