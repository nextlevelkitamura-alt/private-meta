# 全体のgit管理（2repo構成の一望正本）

このMacのAIエージェント運用は **2つの独立したgit repo** に分かれている。
どこに何があり・どこを追跡し・どこへpushするかを、ここで一望する。
（repoの現在地は `~/Private/projects/{active,paused,archive}/` の実体、移動履歴は `../repo-registry/logs/` が正本。ここは横断の全体像だけ。）

## 2つのrepo

- **private-meta** … `~/Private` の外側repo。
  - remote: `github.com/nextlevelkitamura-alt/private-meta`（private）／branch `main`
  - 追跡範囲: 入口 `AGENTS.md`/`CLAUDE.md`・`personal-os/AGENTS.md`・`説明書/`・`my-brain/`（ゴール・areasのAGENTS.md・plans など `.gitignore` で再includeした分）・`projects/` 等。
  - **AIエージェント基盤フォルダは追跡しない**（下記）。
- **ai-agent-foundation** … `personal-os/AIエージェント基盤/` を実体とする別repo。
  - remote: `github.com/nextlevelkitamura-alt/ai-agent-foundation`（private）／branch `main`
  - 追跡範囲: `hooks/`・`skills/`・`loops-registry/`・`repo-registry/`・`global-skill-registry/`・`git-registry/`・`GLOBAL_AGENTS.md` 等、AIエージェント基盤配下すべて。
  - **hooks/session-board 等の基盤作業はすべてこのrepoに入る**。

## なぜ基盤の変更が private-meta に出ないか

- `~/Private/.gitignore` が `/personal-os/*` を無視し、必要な一部mdだけ `!` で再includeしている。**AIエージェント基盤は再includeしていない**。
- かつ `personal-os/AIエージェント基盤/` は自前の `.git` を持つ**別repo**。
- よって private-meta が追跡する基盤ファイルは **0件**。GitHubアプリで private-meta を開いても基盤フォルダは出ない。基盤の変更は **ai-agent-foundation** 側に出る。

## push先・ブランチ・2repoにまたがる変更

- 両repoとも `main`。**push は明示依頼があるときだけ**（session-board の終了確認①②③④での人間OKも明示依頼にあたる）。
- commit前確認: `main`直か作業branchか・`git add -A`を避けパス指定・secret混入なし・push可否。
- 1つの作業が2repoにまたがることがある。**各repoで別々にcommitし、本文で相手repoの変更に触れて束ねる**（例: 基盤側にhook実装commit＋private-meta側に計画記録commit）。
- area計画のrepo卒業は2コミット（移行先で作成commit → area側で削除＋移行ログcommit）。詳細は `~/Private/personal-os/my-brain/areas/AGENTS.md` §5。

## スマホ（GitHubアプリ）での見方

- 見たい対象のrepoを**個別に開く**（2repoは別々に表示される）。
- **「コミット」** … push直後に最新が並ぶ（＝リアルタイム確認）。
- **「コード」** … フォルダ構成をブラウズ。
- hooks/基盤の変更を見るなら **ai-agent-foundation** を★Starして固定。private-metaは `~/Private` 全体（デイリー・計画・projects）の履歴。

## 正本の切り分け（二重管理しない）

- **このdoc** … 横断の全体像（2repo構成・追跡範囲・push・閲覧）の正本。
- `../repo-registry/logs/` … repo移動・登録・削除の履歴ログ。
- `~/Private/projects/{active,paused,archive}/` … repoの現在地の正本（実体配置）。
- 各repoの `AGENTS.md` … そのrepo内のgit運用。基盤 `../AGENTS.md` のgit節はこのdocへのポインタ。
