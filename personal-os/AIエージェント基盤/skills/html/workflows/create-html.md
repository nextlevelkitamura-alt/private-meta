# 通常HTML作成

回答・作業結果を、見て終わり・共有して終わりの1枚HTMLにする。

## 1. 対象を確認する

1. `/html` で指定された直前の内容、またはHTML化を依頼された内容を入力にする。
2. 正本md、デイリー、計画、Notion同期対象、継続編集する文書はHTMLで置き換えない。
3. バックエンドやデータ保存が必要なら、表示専用Artifactの対象外と伝える。

## 2. quick / fullを選ぶ

1. 一度見て終わる説明・簡単なレポート・現在の計画は `references/mode-quick.md`。
2. メタ的情報・繰り返し参照する重要資料・恒久的に残すものは `references/mode-full.md`。
3. 迷ったらquickにする。

## 3. HTMLを作る

1. `references/html-structure.md` のArtifact制約・部品の選択ラダー・表の条件・節の型に従う。
2. 選んだ `references/mode-quick.md` または `references/mode-full.md` に従う。
3. `assets/artifact-template.html` を骨組みにし、使う部品だけ残す。
4. 外部リソース・JS・バックエンドを使わず、self-containedな単一ページにする。
5. secret・token・credential・認証値を含めない。

## 4. 確認して提示する

1. PCで表示とレイアウト崩れを確認する。
2. チャット表題を付けたArtifact URL、またはローカルHTMLのリンクを提示する。
3. スマホ・ブラウザ・URL表示の明示依頼時だけ `workflows/mobile-preview.md` を実行する。
4. スマホ表示ではHTTPS接続・HTTP 200・HTML title一致・tmux稼働を確認してからURLを提示する。
