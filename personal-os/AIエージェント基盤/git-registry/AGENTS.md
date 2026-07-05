# git-registry — 全体git構成の一望

このMacのAIエージェント運用の**横断的なgit構成**（1repo・追跡範囲・push・スマホ閲覧）を一望する正本を置く。

## 役割

- `git-overview.md` … `~/Private` 単一repo（private-meta）の全体像の正本（2026-07-05に旧 ai-agent-foundation を統合）。

## 境界（二重管理しない）

- repoの**現在地**は `~/Private/projects/{active,paused,archive}/` の実体が正本。ここには書かない。
- repoの**移動・登録・削除の履歴**は `../repo-registry/logs/` が正本。ここには書かない。
- 各repoの**内部のgit運用**は各repoの `AGENTS.md`。ここは横断の全体像だけ。
- 基盤 `../AGENTS.md` のgit節は `git-overview.md` へのポインタ。

## 規律

- 構成を変えたら `git-overview.md` と関連する `AGENTS.md` を同じ作業で更新する。
- secret / token / 認証値は書かない。
- `CLAUDE.md` は `AGENTS.md` への相対symlink。
