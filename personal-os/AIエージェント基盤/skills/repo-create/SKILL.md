---
name: repo-create
description: repoを新しく作る、または既存repoを評価してAIが作業しやすい状態へ整える。AGENTS.md/CLAUDE.md、最小フォルダ、GitHub接続、repo-registry確認までを扱う。Use when 新しいrepoを作る, 既存repoを整える, AGENTS.mdを見直す, CLAUDE.mdを確認する, remote/upstreamを確認する。Skill作成・削除・改名・移行は対象外。
---

# repo-create

repoを作る、または既存repoをAIが作業しやすい状態へ整えるSkill。

## 1. 役割

1. 新しいrepoを作る時の初期構成を整える。
2. 既存repoを見て、分かりづらい構成や古い `AGENTS.md` を直す。
3. `AGENTS.md` / `CLAUDE.md`、最小フォルダ、`.gitignore`、Git状態、remote/upstreamを確認する。
4. 北村環境の管理対象repoなら、`repo-registry` の更新要否を確認する。
5. 人間が読んで分かりづらい構成を増やさない。

## 2. Workflow

まずこの `SKILL.md` だけを読み、どちらか1本のworkflowを選ぶ。

1. `workflows/create-repo.md`: 新しいrepoを作る時に使う。repo名、置き場、初期ファイル、GitHub接続、repo-registry更新要否まで確認する。
2. `workflows/improve-repo.md`: 既存repoを評価して改善する時に使う。repo状態、`AGENTS.md`、`CLAUDE.md`、最小フォルダ、Git安全性を見て、必要な修正を最小で行う。

## 3. References

referenceは2つだけ。増やす前に、この2つへ統合できないか確認する。

1. `references/agents-md-criteria.md`: `AGENTS.md` の書き方、repo種別、業務運用repo / coding repoの評価基準。
2. `references/repo-safety.md`: Git、GitHub、secret、削除、repo-registry、pushの安全ルール。

## 4. 対象外

1. アプリ本体の実装。
2. repoの物理移動。必要なら `repo-relocation` を使う。
3. Skill作成、削除、改名、移行。必要なら `skill-creator-custom` / `skill-delete` を使う。
4. Medium/Largeの開発の入口判断・進行管理。必要なら `plan-triage` / `cockpit-supervisor` を使う。
5. 本番deploy、DB migration、secret設定。

## 5. 絶対ルール

1. 人間が分からない構成を、AIにだけ分からせようとしない。
2. `AGENTS.md` は短く、具体的に、次に何をすればよいか分かる形にする。
3. `CLAUDE.md` は同階層の `AGENTS.md` への相対symlinkにする。本文コピーは禁止。
4. 既存ファイルは上書きせず、必要な差分だけ当てる。
5. 構成、正本、plans、logs、registryを変えたら、関連する `AGENTS.md` の整合性も同じ作業単位で見る。
6. repo-registry logsを作成または更新する場合は、本文に `日付時刻: YYYY-MM-DD HH:mm JST` を書き、ファイル名を `YYYY-MM/MM-DD-<repo-id>.md` にする。
7. 危険操作は `references/repo-safety.md` に従い、人間承認なしに実行しない。

## 6. 出力

1. 対象repoと目的。
2. repo種別。
3. 見つけた問題。
4. 変更した内容、または提案した最小修正。
5. `AGENTS.md` / `CLAUDE.md` の状態。
6. repo-registry更新の有無。
7. Git状態と残タスク。
