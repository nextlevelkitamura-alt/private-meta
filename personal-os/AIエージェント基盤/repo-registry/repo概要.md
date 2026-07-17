# repo概要

対象repoの役割と正本への導線をまとめた短い索引。**各repoの詳細・現在状態はそのrepoの `AGENTS.md` が正本**（ここは定型4行のポインタのみ・二重管理しない）。

各エントリは定型4行（役割/場所/入口/登録）で書く。`場所:` は `~/Private` からの相対パス、`登録:` は `repo-registry/` からの相対パスをbacktickで書く（`skills/repo-create/scripts/repoctl-check.sh` がこの2行を機械突合する）。repoの登録・移動・archive時は、同一作業単位でこの索引を更新する（責務は `AGENTS.md` §1）。

## Private

- 役割: `personal-os`（my-brain・計画・進捗・意思決定）と `projects/`（実装repo群の配置先）を含む個人の中枢repo（repo-id: private-meta）
- 場所: `.`
- 入口: `AGENTS.md`
- 登録: `logs/repositories/registered/2026-07/07-17-private-meta.md`

## AIエージェント基盤

- 役割: Global Skill・loop・hook・registryなどグローバル/基盤レイヤの正本（旧ai-agent-foundation・2026-07-05にPrivateへgit統合）
- 場所: `personal-os/AIエージェント基盤/`
- 入口: `personal-os/AIエージェント基盤/AGENTS.md`
- 登録: `logs/repositories/registered/2026-06/06-28-ai-agent-foundation.md`

## 仕事

- 役割: ネクストレベルキャリア事業部CA業務を支援するAIアシスタント（LINE返信・候補者パイプライン等。repo-id: shigoto）
- 場所: `projects/active/仕事/`
- 入口: `projects/active/仕事/AGENTS.md`
- 登録: `logs/repositories/registered/2026-07/07-17-shigoto.md`

## focusmap

- 役割: AIが管理・実行し人間は俯瞰・承認するダッシュボード（旧shikumika）
- 場所: `projects/active/focusmap/`
- 入口: `projects/active/focusmap/AGENTS.md`
- 登録: `logs/repositories/registered/2026-06/06-28-focusmap.md`
