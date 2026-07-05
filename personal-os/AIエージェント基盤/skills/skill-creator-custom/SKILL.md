---
name: skill-creator-custom
description: Skillライフサイクルの窓口。新規Skill作成、既存Skillの改善・修正・レビュー、Skill横断スキャン、Skill移行・改名・削除、runtime露出、logs/catalog/所有repo側導線の確認、既存Skillとの重複・矛盾確認、Global/repo-local判断に使う。削除実行はskill-deleteへ、Codex専用Skillはskill-creator-codexへ委譲する。使用場面はSkill作成, Skill改善, Skill修正, Skillレビュー, Skill横断スキャン, Skill移行, Skill改名, Skill削除。
---

# skill-creator-custom

Skillの作成・改善・棚卸し・移行の窓口。下の振り分けで該当workflowを1つ選んで読む。判断基準は `references/`、実行手順は `workflows/` にある。

## 1. 絶対ルール

1. フォルダは `SKILL.md` ＋ `workflows/` `references/` `assets/` `scripts/` 以外を作らない（`evals/` は公式評価ツール実行時のみ例外）。人間向けの `SKILL.html` だけがフォルダ直下の例外ファイル。
2. `SKILL.md` はrouterに徹し70行以内。判断基準は `references/`、手順は `workflows/` へ出す。
3. 正本（plans・logs・catalog・配置）の運用ルールをこのSkillにコピーしない。参照のみにする。
4. 削除・移動・改名・symlink変更は人間の明示承認を必須にする。
5. Skill編集の完了条件は `SKILL.html` の再生成まで（`references/create-rules.md` §8）。

## 2. Workflow振り分け

1. 新しく作る・手順をSkill化する → `workflows/create-new.md`（`references/create-rules.md` を併読）。
2. 既存Skillを直す・軽くする・description改善・レビュー → `workflows/review-skill.md`（`references/review-rules.md` を併読）。
3. 棚卸し・重複スキャン（Global / repo-local） → `workflows/scan.md`。
4. 移す・改名・runtime露出変更 → `workflows/migrate-skill.md`。

## 3. 委譲

1. 削除が主目的 → `skill-delete`。
2. Codex専用Skill（`agents/openai.yaml` 生成・`quick_validate` 検証） → `skill-creator-codex`。ライフサイクル判断（Global/repo-local・重複/矛盾・移行・改名・削除）は本Skillが窓口のまま担う。

## 4. 迷ったら

1. 対象pathや目的が曖昧なら、推測せず短く確認する。
2. 「作る」か「直す」か迷ったら、対象Skillが既に存在するなら `review-skill.md` へ。
3. 正本配置・runtime露出・registry運用の詳細は再定義せず、`references/create-rules.md` 冒頭が案内する正本を読む。
