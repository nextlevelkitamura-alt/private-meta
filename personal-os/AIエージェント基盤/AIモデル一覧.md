# AIモデル一覧 — サブスクと使い分けの正本

契約中のAIサブスクと、役割ごとのモデル/runtimeを示す1枚。モデル選定はここを参照し、各計画・Skill・フローに本文をコピーしない。
当日の担当・残量・進行中レーンは当日デイリー/session-boardが持つ。判断経緯は `../my-brain/areas/ai運用/決定ログ.md` #11 を参照する。

## サブスク（契約中）

| 提供元 | 利用面 | 契約プラン | 主なモデル |
|---|---|---|---|
| Anthropic | Claude Code / Desktop | Max | Fable 5 / Opus 4.8 / Sonnet 5 |
| OpenAI | Codex Desktop / CLI | プラン名は人間確認後に記入 | Codex |

## 役割 → モデル

- 判断・企画・設計壁打ち: claude/fable5
- 指揮・通常の対話作業: claude/opus4.8
- 実装: claude/sonnet5
- レビュー: codex
- 他レーンを待たせるクリティカルパスだけ、指揮官が実装モデルの格上げを明示する。

## 運用

- ボードの who 列（runtime/model）は `fable5` / `opus4.8` / `sonnet5` / `codex` を使う。
- サブスクまたは役割の変更は決定ログに1件残し、同じ作業単位でこの一覧を更新する。
