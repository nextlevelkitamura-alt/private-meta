# AIモデル一覧 — サブスクと使い分けの正本

契約中のAIサブスクと、役割ごとのモデル/runtimeを示す1枚。役割方針と既定モデルの正本はここに置き、各計画・Skill・フローへ同じ選定基準をコピーしない。実行機構はこの一覧に従うモデルID・effortだけを実装上の引数として持ち、別の役割既定を作らない。
当日の担当・残量・進行中レーンは当日デイリー/session-boardが持つ。判断経緯は `../my-brain/areas/ai運用/決定ログ.md` #11 を参照する。

## サブスク（契約中）

| 提供元 | 利用面 | 契約プラン | 主なモデル |
|---|---|---|---|
| Anthropic | Claude Code / Desktop | Max | Fable 5 / Opus 4.8 / Sonnet 5 |
| OpenAI | Codex Desktop / CLI | プラン名は人間確認後に記入 | Codex |

## 役割 → モデル

- 判断・企画・設計壁打ち: claude/fable5
- 指揮・通常の対話作業: claude/opus4.8
- 実装（委譲）: codex（既定モデル=gpt-5.6-terra・reasoning high。既定の正本は `~/.codex/config.toml`。計画本文・agent定義へモデルIDを埋め込まない）。**codex不安定時はclaude/sonnet5サブエージェントへ切替**（評価も同様・#28）
- レビュー: codex exec直駆動・実装とは別スレッドの独立read-only（実装がcodexでもスレッド分離と読み専用で独立性を担保。サブエージェント経由にしない）。reasoning effortは評価ラウンド=medium・実装/修正=high（2026-07-16 #27）
- 他レーンを待たせるクリティカルパスだけ、指揮官が実装モデルの格上げ（claude系での直接実装など）を明示する。

## 運用

- ボードの who 列（runtime/model）は `fable5` / `opus4.8` / `sonnet5` / `codex` を使う。
- サブスクまたは役割の変更は決定ログに1件残し、同じ作業単位でこの一覧を更新する。
