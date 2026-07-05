# Global Skill Catalog

このディレクトリは、Global Skillの現在索引を置く。Skill本文、作成履歴、計画、runtime露出先ではない。

## 1. ファイル

1. `meta.md`: AIの進め方、判断、調査、レビュー、オーケストレーション、Skill運用、repo運用、runtime運用、技術運用を扱うGlobal Skill。
2. `applied.md`: 資料、字幕、返信文、要約、提案、投稿、リストなど、業務成果物を直接作るGlobal Skill。

## 2. 書くこと

Global Skillごとにblock形式で書く。

```md
## スキル名: `skill-name`
概要: 1〜2行で何をするSkillかを書く。
近接・注意: 必要な場合だけ、重複候補や役割分担を1行で書く。
```

## 3. 書かないこと

1. repo-local Skill。
2. Skill本文の長い要約。
3. 作成、移行、削除の履歴。
4. runtime露出先。
5. 古いTODO、diff、会話ログ。

## 4. 更新ルール

1. Global Skillを新規作成、移行、削除、改名したら同じ作業単位で更新する。
2. 分類が変わる場合は、旧ファイルから削除し、新ファイルへ移す。
3. 削除済みSkillはcatalogに残さない。履歴は `../logs/` を見る。
4. 登録がない場合は、空tableを置かず `現時点で登録なし。` だけを書く。
5. 更新不要の場合は、最終報告で理由を短く説明する。
