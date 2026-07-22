---
name: html
description: 回答・作業結果・実装や変更の説明を、人間が見る1枚もののself-containedなHTMLへ整えるSkill。レポート・調査まとめ・比較・ダッシュボード・実装説明のどれも共通のサンドイッチ構造（結論→先に質問→図解中心の説明→推奨つき再質問）で作り、読者は「コーディングしないがGO/NGを判断する人」を想定する。実装・変更の説明では人間の合意まで対象を編集しない。正本mdや同期対象の置き換え、軽い依頼整理、問いで詰める壁打ちには使わない。
---

# html

回答・作業結果を「見て分かる1枚HTML」にする窓口。型は1つ（サンドイッチ構造）で、モード選択や合言葉は無い。

## 1. 入口

1. `/html`、レポート、調査まとめ、ダッシュボード、比較、図解、実装・変更の説明 → `workflows/create-html.md`（1本道）。
2. 「分かるまで説明して」「実装前に構成を見せて」も同じ1本道。実装説明の必須要素と合意の回し方は `references/impl-explain.md` が担う。
3. 軽い依頼整理は `naiyou-suriawase`、問いで詰める壁打ちは `grill-me` を使う。

## 2. 共通の出力

1. 既定はPC前提・self-containedなArtifact。Artifactが使えないruntimeではローカルHTMLを提示する。
2. すべてのHTMLを必ず白背景のライト単色で作る。暗い背景、表示環境による暗色切替、内容による配色例外は作らない。
3. 正本md・同期対象・継続編集する文書をHTMLで置き換えない。
4. スマホ・ブラウザ・URL表示の明示依頼時だけ `workflows/mobile-preview.md` を使う。

## 3. 共通の安全方針

1. secret・token・credential・認証値をHTMLに含めない。
2. スマホURLは外部公開を伴うため、明示依頼なしに発行しない。
3. commit・push・外部送信はしない。
4. 実装・変更の説明では、人間の合意まで説明対象の実装・削除・移動・改名・symlink変更をしない（`references/impl-explain.md` §2）。

## 4. 直接参照するファイル

1. 共通のHTML規約: `references/html-structure.md`（読者想定・サンドイッチ構造・部品選択ラダー）。
2. 図解レシピ集: `references/diagram-recipes.md`（内容→図の対応表・量の目安。雛形実体はテンプレ側）。
3. 実装説明の型: `references/impl-explain.md`（3点セット・理解ループ・根拠の書き方）。
4. 骨組み: `assets/artifact-template.html`（部品CSSと図解レシピ雛形R1〜R6の正本）。
5. スマホ表示: `workflows/mobile-preview.md` / `scripts/mobile_preview.py`。
