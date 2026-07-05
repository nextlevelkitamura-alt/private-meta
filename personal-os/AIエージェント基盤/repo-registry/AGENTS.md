# Repo Registry

このディレクトリは、repo単位の履歴とrepo-local Skillの履歴を置く。

repoの現在状態は `/Users/kitamuranaohiro/Private/projects/{active,paused,archive}/` の実体配置を正とする。repo-local Skillの本文正本と現在導線は各repo内に置き、このrepoには履歴だけを書く。

## 1. 役割

1. `logs/`: repoとrepo-local Skillの履歴。

repo新規作成、repo改善、所有repo未確定のrepo-local Skill計画は `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/` を見る。

## 2. 境界

1. repo-local Skill本文は各repo内を正本にする。
2. repoとrepo-local Skillの現在状態は各repo側を正とし、このディレクトリで二重管理しない。
3. Global Skill本文とGlobal Skill registryはこのディレクトリでは扱わない。`skills/` と `global-skill-registry/` を見る。
4. 計画書はこのディレクトリに置かず、`/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/` を見る。
5. plans、logs、各repoに同じ情報を重複して書かない。

## 3. 作業前ルーティング

1. `logs/` を触る前に `logs/AGENTS.md` を読む。
2. 計画書を触る前に `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/AGENTS.md` と `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/AGENTS.md` を読む。

## 4. 完了条件

1. repoの現在状態は `/Users/kitamuranaohiro/Private/projects/{active,paused,archive}/` の実体配置で説明できる。
2. repo-local Skillの本文正本と所有repo側の導線が矛盾していない。
3. repo計画と所有repo未確定のrepo-local Skill計画は `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/` 側で説明できる。
4. 必要なログだけが短く更新されている。
5. Global Skillの情報をこのディレクトリに重複管理していない。
6. `CLAUDE.md -> AGENTS.md` のsymlinkが維持されている。
