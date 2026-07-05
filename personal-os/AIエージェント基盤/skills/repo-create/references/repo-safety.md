# repo safety

repo作成・改善で守る安全ルール。

## Git

1. 作業前後に `git status --short` を見る。
2. 既存の未コミット変更を勝手に戻さない。
3. 関係ない差分をstageしない。
4. 既存remoteは勝手に張り替えない。
5. push前にremote、upstream、branchを確認する。

人間承認なしに実行しない:

1. `git push --force`
2. `git reset --hard`
3. `git clean -fd`
4. push to `main`
5. merge、cherry-pick、rebase into `main`
6. branch削除
7. worktree削除
8. remote branch削除
9. remote URL張り替え

## Secret

1. `.env`、token、credential、secretの値を表示しない。
2. secretをcommitしない。
3. `.env.example` は値なしの例だけにする。

## GitHub

1. 新規GitHub Repositoryは、ユーザーがpublicを明示しない限りprivateにする。
2. repo名はASCII kebab-caseを推奨する。
3. 日本語名や説明はREADMEやdescriptionへ書く。
4. GitHub ProjectとRepositoryを混同しない。

## 北村環境

1. 新しいrepo本体は原則 `/Users/kitamuranaohiro/Private/projects/active/` 配下に置く。
2. `/Users/kitamuranaohiro/Private` 直下にはrepo本体を増やさない。
3. repoの物理移動は `repo-relocation` を使う。
4. 管理対象repoとして登録・移動・削除した場合は、`/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/logs/` の更新要否を確認する。

## AGENTS整合性

1. `AGENTS.md` を作成または更新したら、同階層の `CLAUDE.md -> AGENTS.md` を確認する。
2. フォルダ構成を変えたら、`AGENTS.md` のフォルダ概要も確認する。
3. 正本、plans、logs、catalog、registryの置き場を変えたら、関連する入口説明を古いままにしない。
