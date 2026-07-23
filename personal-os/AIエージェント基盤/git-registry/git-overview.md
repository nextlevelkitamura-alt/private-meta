# 全体のgit管理（1repo構成の一望正本）

このMacのAIエージェント運用は **`~/Private` の単一git repo（private-meta）** で管理する。
（2026-07-05に旧 `ai-agent-foundation`（基盤の別repo）を統合。1repoに一本化して「基盤の変更がprivate-metaに出ない」ややこしさを解消した。）
repoの現在地は `~/Private/projects/{active,paused,archive}/` の実体、移動履歴は `../repo-registry/logs/` が正本。ここは横断の全体像だけ。

## repo

- **private-meta** … `~/Private` の唯一のrepo。
  - remote: `github.com/nextlevelkitamura-alt/private-meta`（private）／branch `main`
  - 追跡範囲: 入口 `AGENTS.md`/`CLAUDE.md`・`personal-os/`（`AIエージェント基盤/`全体と`.gitignore`で許可した`my-brain`）・`projects/` 等。
  - **AIエージェント基盤（hooks / skills / loops-registry / repo-registry / git-registry / global-skill-registry / GLOBAL_AGENTS.md 等）もこのrepoに入る**。

## 追跡範囲（.gitignore方針）

- `~/Private/.gitignore` は `/*`（トップレベル全無視）から `!` で許可を積む allowlist 方式。
- `personal-os/*` を無視し、必要分だけ再include（入口AGENTS・ゴール・areasのAGENTS/plans）。
- **`personal-os/AIエージェント基盤/**` は全追跡**（2026-07-05統合）。基盤内の揮発物（tmp/outputs/state/run-card/`__pycache__`）はネストした `AIエージェント基盤/.gitignore` が除外する。
- 新しいareaを足したら `.gitignore` に同じ許可ブロックを追記する（忘れると新規ファイルが静かに無視される）。

## push先・ブランチ・またぐ変更

- `private-meta` の `main` のみ。依頼範囲の変更は、検証・secret確認・対象限定stageを通した後、AIがcommitして通常pushまで完了する。
- commit前確認: `main`直か作業branchか・`git add -A`を避けパス指定・secret混入なし・remote/branch・push後のreadback。
- area計画の実装repoへの卒業は、移行先repoとまたがる2コミットになる（移行先で作成commit → area側で削除＋移行ログcommit）。詳細は `~/Private/personal-os/my-brain/areas/AGENTS.md` §5。

## スマホ（GitHubアプリ）での見方

- `private-meta` を開けば **全部**見える（基盤も含め1repoに一本化）。★Starして固定。
- **「コミット」** … push直後に最新が並ぶ（＝リアルタイム確認）。**「コード」** … フォルダ構成をブラウズ。

## 履歴の注記（統合前）

- 2026-07-05以前、`personal-os/AIエージェント基盤/` は別repo `ai-agent-foundation`（remote 同アカウント）だった。過去履歴はGitHubの同repo（**archive・参照専用**）とローカル退避 `personal-os/.aaf-git-backup-20260705/`（非追跡）に残る。統合後の `private-meta` の履歴には引き継いでいない（「シンプル」統合）。

## 正本の切り分け（二重管理しない）

- **このdoc** … git構成（1repo・追跡範囲・push・閲覧）の正本。
- `../repo-registry/logs/` … repo移動・登録・削除の履歴ログ。
- `~/Private/projects/{active,paused,archive}/` … repoの現在地の正本（実体配置）。
- 基盤 `../AGENTS.md` のgit節はこのdocへのポインタ。
