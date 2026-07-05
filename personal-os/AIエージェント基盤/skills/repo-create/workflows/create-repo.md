# create repo

新しいrepoを作る時に使う。目的は、repoを増やすことではなく、人間とAIが迷わず扱える最小構成を作ること。

## 手順

1. repo名、目的、公開範囲、置き場を確認する。
2. 置き場は原則 `/Users/kitamuranaohiro/Private/projects/active/` 配下にする。例外が必要なら理由を確認する。
3. `references/agents-md-criteria.md` を読み、repo種別を決める。
4. `references/repo-safety.md` を読み、GitHub、secret、削除、pushの危険操作を確認する。
5. 最小ファイルだけ作る。
   - `AGENTS.md`
   - `CLAUDE.md -> AGENTS.md`
   - `README.md`
   - `.gitignore`
   - 必要な場合だけ `plans/`、`docs/`、`scripts/`
6. `AGENTS.md` は `references/agents-md-criteria.md` の型に合わせる。
7. Git初期化、remote追加、GitHub Repository作成が必要か確認する。既存remoteは勝手に張り替えない。
8. 北村環境の管理対象repoなら、`repo-registry/logs/` の登録ログ更新要否を確認する。
9. 作成後に `git status --short` を確認する。

## 出力

1. 作成したrepo path。
2. repo種別。
3. 作成したファイル。
4. `AGENTS.md` / `CLAUDE.md` の状態。
5. GitHub接続の状態。
6. repo-registry更新の有無。
7. 残タスク。

## 禁止

1. 目的が曖昧なままrepoを作らない。
2. `/Users/kitamuranaohiro/Private` 直下にrepo本体を作らない。
3. public repoを既定にしない。
4. secretやtokenを作成、表示、commitしない。
5. push to `main` やremote張り替えを人間承認なしに行わない。
