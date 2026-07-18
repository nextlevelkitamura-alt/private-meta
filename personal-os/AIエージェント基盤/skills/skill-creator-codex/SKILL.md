---
name: skill-creator-codex
description: Codex向けSkillの新規作成、既存Skill更新、bundled resources設計、agents/openai.yaml生成、quick_validate検証を支援する。Use when ユーザーがCodexで使うSkillを作りたい、SKILL.mdを更新したい、scripts/references/assetsを整理したい、Skillの発火条件やメタデータを改善したいとき。
metadata:
  short-description: Codex用Skillの作成・更新
---

# Skill Creator Codex

OpenAI/Codex 公式の `skill-creator` を、日本語でのCodex運用向けに改編したSkill。
Codexで使うSkillを作る、既存Skillを改善する、発火条件や同梱リソースを整理する作業を支援する。

Claude固有の評価ランナーやAnthropic専用のSkill仕様は扱わない。CodexのSkill仕様、`agents/openai.yaml`、`scripts/quick_validate.py` を中心に使う。

Skillライフサイクルの窓口（新規作成・改善・移行・改名・削除の入口、Global / repo-local 判断、既存Skillとの重複・矛盾確認）は `skill-creator-custom`。本Skillはそこから委譲された Codex 固有作業（`agents/openai.yaml` 生成・`quick_validate` 検証・bundled resources 設計）を担う。ライフサイクル判断で迷ったら `skill-creator-custom` に戻す。

## Skillの考え方

Skillは、Codexに特定領域の手順、判断基準、ツール利用方法、参照資料を渡すための自己完結したフォルダ。
一般的な知識ではなく、Codexがその場で推測しにくい運用手順、社内ルール、検証方法、再利用コードを入れる。

Skillが提供するもの:

1. 専門ワークフロー: 領域固有の手順や分岐
2. ツール連携: ファイル形式、API、CLI、MCPの扱い方
3. ドメイン知識: スキーマ、業務ルール、社内判断基準
4. 同梱リソース: `scripts/`、`references/`、`assets/`

## 基本原則

### 短く保つ

コンテキストは共有資源。Skill本文は、システムプロンプト、会話履歴、他Skillのメタデータ、実際の依頼と同じコンテキストを消費する。

Codexはすでに十分に賢い前提で書く。一般論、冗長な説明、明らかな注意書きは削る。
「この情報がないとCodexが間違えるか」「この段落はトークン消費に見合うか」を基準に残す。

### 自由度を調整する

作業の壊れやすさに応じて、指示の粒度を変える。

- 高い自由度: 判断が文脈依存で、複数の正解がある作業。文章指示で十分。
- 中くらいの自由度: 推奨パターンはあるが、入力によって変える余地がある作業。疑似コードや設定例を置く。
- 低い自由度: 手順ミスが危険、再現性が重要、毎回同じ処理が必要な作業。実行scriptを置く。

### 検証可能にする

Skillは書いて終わりにしない。作成後は `scripts/quick_validate.py` を実行し、可能なら実際にSkillを使う想定プロンプトで確認する。
scriptを追加した場合は、少なくとも代表ケースを実行して動作を確認する。

## Skillの構造

標準構造:

```text
skill-name/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── scripts/
├── references/
└── assets/
```

必須:

- `SKILL.md`: frontmatterと本文。CodexがSkill発火後に読む中心ファイル。

推奨:

- `agents/openai.yaml`: UI表示名、短い説明、default promptなどのCodex向けメタデータ。

任意:

- `scripts/`: 再現性が必要な処理、毎回書き直すと危険な処理。
- `references/`: 必要時だけ読む詳細資料、仕様、スキーマ、ポリシー。
- `assets/`: 出力に使うテンプレート、画像、フォント、雛形プロジェクト。

README、INSTALLATION_GUIDE、CHANGELOGなど、Skill実行に直接必要ない補助文書は原則作らない。

## SKILL.md

`SKILL.md` はYAML frontmatterとMarkdown本文で構成する。

frontmatterの基本:

```yaml
---
name: my-skill
description: 何をするSkillか。Use when いつ使うか、どんな依頼で発火すべきか。
---
```

`description` は最重要の発火条件。本文は発火後にしか読まれないため、「いつ使うか」は本文ではなくdescriptionに入れる。

書き方:

- `name` は小文字、数字、ハイフンのみ。
- フォルダ名と `name` を一致させる。
- `description` には what と when を両方入れる。
- 1024字以内にする。
- 本文は200行未満を目標にし、500行を超えない。

## agents/openai.yaml

`agents/openai.yaml` はCodex UIやハーネス向けの補助メタデータ。
生成・更新前に `references/openai_yaml.md` を読む。

生成例:

```bash
scripts/generate_openai_yaml.py path/to/skill \
  --interface display_name="Skill Name" \
  --interface short_description="25-64 characters summary" \
  --interface default_prompt="Use $skill-name to ..."
```

更新時は、`SKILL.md` の内容と `agents/openai.yaml` がずれていないか確認する。
アイコンやブランドカラーなどの任意フィールドは、ユーザーが明示した場合だけ入れる。

## bundled resources

### scripts

同じコードを毎回書く処理、壊れやすい処理、決定的に実行したい処理は `scripts/` に置く。

例:

- PDFの回転や結合
- frontmatter検証
- APIレスポンス整形
- テンプレート生成

scriptを置いたら実行確認する。環境差分がありうる場合は、必要な前提をSkill本文かscriptのhelpに短く書く。

### references

詳細な仕様、長い業務ルール、スキーマ、API仕様は `references/` に置く。
`SKILL.md` には「いつ読むか」だけを書く。

例:

- `references/schema.md`: DBやBigQueryのスキーマ
- `references/api.md`: API仕様
- `references/policy.md`: 判断基準や禁止事項

長いreferenceには冒頭に目次か検索キーワードを書く。
referenceは1階層に留め、深い参照チェーンを作らない。

### assets

出力物に使う素材は `assets/` に置く。Codexが読む資料ではなく、コピー・加工して使うものとして扱う。

例:

- PowerPointやDOCXテンプレート
- フロントエンド雛形
- ロゴ、画像、フォント
- サンプル入力ファイル

## 作成ワークフロー

### 1. 用途を具体化する

新規Skillでは、最初に次を確認する。

1. 何をするSkillか
2. どんな依頼で発火するべきか
3. 入力は何か
4. 出力は何か
5. 書き込み、送信、削除などの副作用があるか
6. 依存するCLI、MCP、API、scriptがあるか
7. 既存Skillの更新で足りないか
8. どこを正本にするか

用途が明確な既存Skillの更新なら、この確認は必要な範囲に絞る。

北村環境で中〜大規模なGlobal Skill作成・改善になる場合は、先に `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/AGENTS.md` と `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/AGENTS.md` を読み、計画書を `ai運用/plans/active/<YYYY-MM-対象>/plan.md` に置く。状態はバケットで持ち、plan.md に `状態:` フィールドは書かない。
既存Skill改善の計画書ファイル名は、日付の後に対象Skill名を入れ、続けて日本語の改善内容を書く。
北村環境でGlobal Skillとして長期運用する場合は、必要に応じて `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`、`/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md`、`/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/logs/AGENTS.md`、`/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/catalog/AGENTS.md` も読む。

### 2. 同梱リソースを設計する

想定プロンプトを2、3個置き、それぞれをゼロから実行する場合に何が必要か考える。

- 毎回同じコードを書くなら `scripts/`
- 長い仕様を参照するなら `references/`
- テンプレートや素材を再利用するなら `assets/`
- どれも不要なら `SKILL.md` だけにする

リソースを増やすこと自体を目的にしない。

### 3. Skillを初期化する

完全新規なら `scripts/init_skill.py` を使う。

```bash
scripts/init_skill.py my-skill --path "${CODEX_HOME:-$HOME/.codex}/skills"
scripts/init_skill.py my-skill --path "${CODEX_HOME:-$HOME/.codex}/skills" --resources scripts,references
scripts/init_skill.py my-skill --path ~/work/skills --resources scripts --examples
```

作成先が指定されていない場合は、ユーザーに確認する。`~/.codex/skills`（=`$CODEX_HOME/skills`）はCodexが自動で読む一時置き場（scratch）で、Codex単体で使い捨てる試作だけここに置く。

北村環境でGlobal Skillとして長期運用する場合は、`~/.codex/skills` に残さない。正本は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/<skill-name>/` に置き、`global-skill-registry/scripts/link-global-skill.sh` で `~/.agents/skills`（Codexはここを読む）・`~/.claude/skills`・`~/.gemini/...` の4窓へdirect symlink露出する。`~/.codex/skills` は露出先にしない。runtime入口を正本にしない。

### 4. 編集する

まず `scripts/`、`references/`、`assets/` の必要最小限を作る。
その後、`SKILL.md` を書く。

本文にはCodexが知らない、または毎回推測すると危険なことだけを書く。
詳細をreferenceへ逃がした場合は、`SKILL.md` に「いつ読むか」を明確に残す。

scriptを追加したら実行する。placeholderや不要なexampleは残さない。

### 5. 検証する

作成・更新後はquick validationを走らせる。

```bash
scripts/quick_validate.py path/to/skill
```

確認すること:

- frontmatterがYAMLとして有効
- `name` とフォルダ名が一致
- `description` が発火条件として十分
- `agents/openai.yaml` がSkill内容と一致
- scriptがある場合、代表ケースで動く
- `SKILL.md` が肥大化していない

### 6. 実利用で改善する

Skillは実タスクで使って改善する。

1. 実際の依頼で使う
2. 迷い、重複、手戻りを観察する
3. `SKILL.md`、script、referenceのどこを変えるべきか決める
4. 変更する
5. 再検証する

## 更新時の注意

- 既存Skillを大改造する前に、差分と影響範囲を確認する。
- 削除、正本移動、symlink張り替え、外部送信、破壊的操作はユーザーの明示承認を取る。
- repo-local Skillを無理にGlobal化しない。
- entry fileやカタログに詳細手順を溜め込まない。
- 既存のAGENTS.md、CLAUDE.md、リポジトリ固有ルールを優先する。

## 最終報告

作成・更新後は、次を短く報告する。

- 作成または更新したSkill名
- 正本パス
- 変更した主なファイル
- `quick_validate.py` の結果
- runtime露出やログを更新した場合、その内容
- 北村環境のGlobal Skill作成・改善では、logs/catalogとPersonal OS plansの更新先または更新不要理由
