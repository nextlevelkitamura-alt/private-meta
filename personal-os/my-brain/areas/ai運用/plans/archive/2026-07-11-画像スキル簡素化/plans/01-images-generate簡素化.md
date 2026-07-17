# 01: images-generate 簡素化（private-meta）

親: [program.md](../program.md)。対象はすべて `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/` 配下。

## やること

### 1. `images-generate/SKILL.md` を全面書き換え（日本語・薄い窓口）

含める内容（この6点だけ・60行以内目安）:
- 役割1行: 画像の生成・編集は Codex 組み込み `image_gen` で行う（Claude 自身は画像を作れないため Codex へ委任する）。
- 生成の基本形（実文コマンド）:
  `codex exec --json --skip-git-repo-check -C <作業dir> "image_gen で <プロンプト> を生成して保存パスを報告"`
  → 出力1行目 `thread.started` の `thread_id` を控える。
- 継続・編集（壁打ち）: `codex exec resume <thread_id> "<修正指示>"` で前の画像を文脈に保ったまま編集できる。新規execを投げ直さない。
- プロンプトのコツ（既存の共通ルールから継承）: 英語で書く／画像内テキストは短い英語（日本語は崩れる）／複数枚は1プロンプト1生成／プロジェクトで使う画像は `~/.codex/generated_images/...` からワークスペースへコピーして最終パスを報告。
- 分岐: 一般画像 → `workflows/general-image.md`／プロダクトUI・画面 → `workflows/mockup.md`。
- フォールバック: `image_gen` が使えない時だけ `references/chatgpt-arc-webbridge.md`。
- frontmatter: `disable-model-invocation: true` は維持。description は新内容に合わせ日本語で書き直す（キャラ・求人の語を除去）。

### 2. `workflows/general-image.md` を書き換え（汎用部分だけ残す）

- 残す: フェーズ0の5項目チェック（アスペクト比・主役・テイスト・用途・テキスト）／不足は1回でまとめて聞く／フェーズ1のプロンプト確定と確認形式／英語プロンプト化／複数枚は1枚ずつ／生成後のコピーと報告／「よくある失敗パターン」のうちプロンプト起因の3行（英語テキスト化・体型誇張・メモ書き混入）。
- 生成実行の記述は image_gen（codex exec）+ resume に差し替える。
- 削除: キャラクター選択の節・prompts.json・job-create・ChatGPT/Gemini CLI・Drive・オプション一覧・副作用・認証切れ対処（→ 02 が仕事repoへ移設するので、このファイルには何も残さない。ポインタも書かない）。

### 3. `workflows/mockup.md` を日本語化して薄く

- 残す（日本語で）: Core Rules → 基本原則／Ambiguity Gate → 曖昧ゲート／mockup type 8分類／Prompt Schema（schema自体は英語のまま可）／Text Handling の要点。
- 削る: Speed/Quality モードの冗長説明・Context Gathering の細目は各3行程度へ圧縮。
- Reference Recipes 節は残す（references/mockup-prompt-recipes.md は無変更）。

### 4. キャラクターの完全削除（人間承認済み）

- `images-generate/references/character-presets.md` を削除。
- `images-generate/assets/characters/` ごと削除（png 2枚）。assets/ が空になったら assets/ も削除。

### 5. 呼び出し元の参照更新

- `sns-post/mode-generate-image.md`:
  - 「yuu_workstyle のキャラクター選択」節（キャラメニュー全体）を削除。
  - 冒頭の連携記述を「生成方式は `images-generate/SKILL.md`（image_gen＋exec resume）に従う」へ書き換え。「キャラクター選択」への言及を除去。
  - sns-post 固有のパイプライン（generate-images.ts・スプシ・Drive・Buffer）はこのファイルの所属通り**残す**（触らない）。
- `slide/SKILL.md` 94行目付近・`slide/light.md` 210行目付近:
  - 「Gemini / ChatGPT で生成して保存・Driveアップロードまで自動化される」等の説明を「Codex `image_gen` で生成する」へ最小修正。
- `images-generate/evals/evals.json`: assertion 中の「prompts.json を作成したり」を「生成コマンドを実行したり」へ最小修正。他は無変更。

## 制約

- 上記以外のファイルに触らない。`references/mockup-prompt-recipes.md`・`chatgpt-arc-webbridge.md`・`agents/openai.yaml` は無変更。
- これらのskillフォルダはgit未追跡。**触った（作成・変更した）ファイルだけを明示パスで `git add`**。フォルダごとaddしない。削除した未追跡ファイルはgit操作不要。
- push しない。コミットは日本語1行＋`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`。

## レビュー項目（こうなっていれば正しい）

1. SKILL.md が日本語で、image_gen 委任・exec resume 継続・プロンプトのコツ・A/B分岐・フォールバックだけを含み、キャラ・求人・prompts.json・Drive の語が無い。
2. general-image.md に5項目チェックとプロンプト確定フローが残り、job-create/CLI/Drive/キャラの記述が無い。
3. mockup.md の見出しと本文が日本語（Prompt Schema のコード部は英語可）。
4. character-presets.md と assets/characters/ が存在しない。
5. sns-post/mode-generate-image.md にキャラクターの節・言及が無く、sns-post固有パイプラインは無傷。
6. rg で skills/ 配下に "ねこみみ|きつね研究員|character-presets|nekomimi|kitsune" がヒットしない（logs/ 履歴を除く）。
7. コミットが明示パスaddのみで、無関係の未追跡ファイル（PROGRESS.md 等）が混入していない。
