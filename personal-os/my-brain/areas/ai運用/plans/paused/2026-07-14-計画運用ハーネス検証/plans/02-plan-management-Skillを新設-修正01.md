親計画: ../program.md ／ 出所評価: `02-plan-management-Skillを新設-評価01.md` ／ ラウンド: 01 ／ 宛先: 子02の実装担当

# 修正01: plan-management Skillを新設

※ 実装担当は口頭要約でなく、このファイルを読んで修正する。

## 修正項目

### `SKILL.md` が70行以内で、3 workflowとregistryを1ホップで参照できる

- 対象: `AIエージェント基盤/skills/plan-management/workflows/manage-program.md` のStep 2・4、および `workflows/review-and-transition.md` のStep 2。
- 今の状態: `plan-ops/new-child.sh`、`plan-ops/progctl.sh`、`plan-ops/check-section.sh` と書かれているが、script実体は `plan-ops/scripts/` 配下にある。
- 期待する状態: 3箇所すべてが、正本Skillから実行可能な `scripts/new-child.sh`、`scripts/progctl.sh`、`scripts/check-section.sh` を一意に案内する。
- 修正方法の指定: 各記述を ``plan-ops` の `scripts/<script>.sh`` に置換する。コマンド、引数、dry-run、判断責務は増減させない。
- やらないこと: `plan-ops` のscript・template・testの移動/改名、`SKILL.md` の責務分離、`SKILL.html`、catalog、作成ログ、runtime symlink、hook接続を変更しない。

## 完了の確認方法

3本のpathがすべて実在すること、旧pathが新Skill内に残らないこと、`program-lint` と `git diff --check` が通ることを評価02で確認する。
