# Short Video Create Skill Requirements

Status: implemented
Created: 2026-06-19

## Problem

縦型ショート動画の制作では、企画、リサーチ、出典確認、素材安全性、TTS、字幕同期、編集、検証が分散しやすい。
既存の `ai-news-short-video` はAIニュース一般に有効だが、より広いショート動画制作では、工程ごとに必要な文脈だけ読むハブSkillが必要になる。初期プリセットとして求人・就職・AI雇用ニュースを扱う。

## Scope

- 新規Skill `short-video-create` を作成する。
- `SKILL.md` は軽量ハブにし、詳細手順は `workflows/`、判断基準は `references/`、雛形は `assets/` に分離する。
- 既存Skillや共通scriptsは変更しない。
- グローバルSkill配置は、起業スキル配下を正本にしたsymlink方式にする。

## Non-Goals

- 投稿・公開の自動化はしない。
- 有料APIの有効化や課金設定はしない。
- 動画生成/編集の業務共通スクリプトはこの作業では作らない。
- 既存 `ai-news-short-video` の責務を広げない。

## Acceptance Criteria

- `skills/short-video-create/SKILL.md` が存在し、200行前後以下のハブ構成になっている。
- `workflows/` に preproduction, research-and-sources, storyboard, production, revision, skill-memory がある。
- `references/` に source-policy, video-style, voice-caption-policy, qa-checklist, directory-structure がある。
- `assets/` に storyboard-template, project-template, asset-ledger-template がある。
- `SKILL.md` にLoading Policy、Mode Routing、Safety Policy、Hard Rulesがある。
- 日本語記事優先、生成AIを事実証拠にしない、Red素材禁止、字幕最大2行のルールが明記されている。
- `.codex/skills`, `.claude/skills`, `.agents/skills` からsymlinkで参照できる。

## Evidence

- `wc -l` で `SKILL.md` の行数を確認する。
- `find` で新規Skill配下のファイル一覧を確認する。
- `test -L` と `readlink` でグローバルsymlinkを確認する。
