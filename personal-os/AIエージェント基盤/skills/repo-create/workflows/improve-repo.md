# improve repo

既存repoを評価して、AIが作業しやすい状態へ最小修正する時に使う。

## 手順

1. 対象pathを確認する。指定がなければ現在の作業ディレクトリを使う。
2. read-onlyで現状を見る。
   - `pwd`
   - `git rev-parse --show-toplevel`
   - `git status --short`
   - `git branch --show-current`
   - `git remote -v`
   - `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
3. `AGENTS.md` と `CLAUDE.md` を確認する。
4. `references/agents-md-criteria.md` を読み、repo種別と `AGENTS.md` の分かりやすさを評価する。
5. `references/repo-safety.md` を読み、Git、secret、push、registryの危険操作を確認する。
6. 問題を次の3つに分ける。
   - 今すぐ直す: 危険、古い正本、`CLAUDE.md` コピー、secret、破壊的操作許可。
   - 整える: 分かりづらい、長すぎる、フォルダ概要がない、作業の始め方がない。
   - 任意: 便利だが今は不要。
7. 修正は最小にする。`AGENTS.md` を全部書き換えず、必要な見出しとルールだけ直す。
8. フォルダ構成、正本、plans、logs、registryを変えた場合は、関連する `AGENTS.md` の整合性を確認する。
9. 最後に `git status --short` を確認する。

## 出力

1. 対象repo。
2. repo種別。
3. 見つけた問題。
4. 変更した内容、または提案した最小修正。
5. `AGENTS.md` / `CLAUDE.md` の状態。
6. repo-registry更新の有無。
7. Git状態。

## 禁止

1. 分かりづらい構成をさらに分厚い説明でごまかさない。
2. Smallな整理で重いdocs構成やtask-boardを強制しない。
3. 既存remote、branch、worktree、secret、production dataを勝手に変更しない。
4. repo物理移動はこのworkflowで実行しない。必要なら `repo-relocation` を使う。
