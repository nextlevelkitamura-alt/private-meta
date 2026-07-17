---
name: html
description: 回答や作業結果を、人間が見る1枚もののself-containedなHTMLへ整えるSkill。通常のレポート・調査まとめ・ダッシュボード・比較はquick/fullで作成する。メタ構造について「meta-explain」「分かるまで説明して」「この仕組みを説明して」「実装前に構成を見せて」と明示された時は、人間が理解するまで同一HTMLを更新するメタ説明workflowを使い、合意まで対象を編集しない。正本mdや同期対象の置き換え、軽い依頼整理、問いで詰める壁打ちには使わない。
---

# html

回答・作業結果を「見て分かるHTML」にする統合窓口。通常HTML作成と、メタ構造の理解ゲートを別workflowへ振り分ける。

## 1. Workflow振り分け

1. `/html`、レポート、調査まとめ、ダッシュボード、比較、図解 → `workflows/create-html.md`。
2. メタ構造について「meta-explain」「分かるまで説明して」「この仕組みを説明して」「実装前に構成を見せて」と明示 → `workflows/meta-explain.md`。
3. メタ説明workflowは自発起動しない。必要そうな時も提案までに留め、人間の明示依頼か確認後に開始する。
4. 軽い依頼整理は `naiyou-suriawase`、問いで詰める壁打ちは `grill-me` を使う。

## 2. 共通の出力

1. 既定はPC前提・self-containedなArtifact。Artifactが使えないruntimeではローカルHTMLを提示する。
2. すべてのHTMLを必ず白背景のライト単色で作る。暗い背景、表示環境による暗色切替、quick/fullやメタ説明による配色例外は作らない。
3. 正本md・同期対象・継続編集する文書をHTMLで置き換えない。
4. スマホ・ブラウザ・URL表示の明示依頼時だけ `workflows/mobile-preview.md` を使う。

## 3. 共通の安全方針

1. secret・token・credential・認証値をHTMLに含めない。
2. スマホURLは外部公開を伴うため、明示依頼なしに発行しない。
3. commit・push・外部送信はしない。
4. メタ説明workflowでは、人間の合意まで説明対象の実装・削除・移動・改名・symlink変更をしない。

## 4. 直接参照するファイル

1. 共通のHTML規約: `references/html-structure.md`（選択ラダーの1段目は図解判定）。
2. 図解レシピ集: `references/diagram-recipes.md`（内容→図の対応表・量の目安。雛形実体はテンプレ側）。
3. 通常HTMLの品質: `references/mode-quick.md` / `references/mode-full.md`。
4. メタ説明固有の見せ方: `references/meta-explain-layout.md`。
5. 骨組み: `assets/artifact-template.html`（部品CSSと図解レシピ雛形R1〜R6の正本）。
6. スマホ表示: `workflows/mobile-preview.md` / `scripts/mobile_preview.py`。
