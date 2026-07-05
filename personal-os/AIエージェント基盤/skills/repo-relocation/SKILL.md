---
name: repo-relocation
description: 既存repoを別フォルダへ安全に移動し、旧パス互換symlinkを残さず、参照更新、launchd再登録、移動後テスト、repo-registry記録まで進める。Use when repo移動, リポジトリ移動, projects/activeへ移す, launchd移行, 旧パス参照整理。
---

# repo-relocation

既存repoを新しい置き場へ移動するための最小Skill。

## 1. 役割

1. repo移動前に、Git、AGENTS、絶対パス、launchd、runtime参照を確認する。
2. repoを新パスへ移動し、旧パスには互換symlinkを置かない。
3. 旧パスを参照するruntime、設定、launchd、docsを必要な範囲で新パスへ更新する。
4. launchdがあるrepoでは、移動後に新パスで再登録できる入口を作る。
5. 移動後にdry-run、read-only、launchd反応を確認する。
6. 問題があればsymlinkで隠さず、原因を分類してrollbackまたは追加修正を判断する。
7. repo-registryへ、現在profileと移動ログを短く残す。

## 2. Workflow

1. `workflows/move-repo.md`: repoを別フォルダへ移動する時に使う。スキャン、移動、旧パス参照更新、launchd再登録、テスト、repo-registry記録、rollback判断まで扱う。
2. `references/worktree-relocation.md`: 複数worktreeがあるrepoだけ読む、worktree移動時の最小チェックリスト。

## 3. 必ず守ること

1. 対象repoの `AGENTS.md` を先に読む。
2. 移動前に `git status --short --branch`、`git remote -v`、`git worktree list` を確認する。
3. 既存の未コミット変更はユーザー作業として扱い、巻き戻さない。
4. 移動直後も旧パス互換symlinkは作らない。
5. launchd本登録は `--dry-run` と対象ジョブ確認の後に行う。
6. LINE送信、投稿、DB更新、スプレッドシート書き込みなどの外部更新系ジョブは、ユーザーが明示しない限り起動しない。
7. 旧パス参照を残す場合は、理由、残存場所、解消条件を最終報告とrepo-registryログに短く残す。
8. rollbackは `mv` とGit状態確認で行い、旧パス互換symlinkで代用しない。
9. repo-registryに残すのは地図だけにし、コマンド生ログ、diff全文、secretは書かない。
10. repo-registry logsを作成または更新する場合は、本文に `日付時刻: YYYY-MM-DD HH:mm JST` を書き、ファイル名を `YYYY-MM/MM-DD-<repo-id>.md` にする。

## 4. 出力

1. 旧pathと新path。
2. Git状態。
3. 旧パス互換symlinkを作っていないこと。
4. launchdの登録状態とテスト結果。
5. 失敗が移動由来か、既存の認証・外部サービス由来かの分類。
6. repo-registryの更新先。
7. 旧パス参照の残存有無。
8. rollback手順と実行要否。

## 5. 近いSkill

1. `repo-create`: 新規repo作成と初期設定を扱う。既存repo移動はこのSkillで扱う。
2. `repo-create`: `AGENTS.md` の整備を扱う。repo移動全体の実行はこのSkillで扱う。
3. `skill-creator-custom`: Skill作成やregistry運用を扱う。このSkill自体の改善時に使う。
