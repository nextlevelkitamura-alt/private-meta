分類: skill ／ 種別: 統合整理
規模: ライト

# htmlメタ説明統合

## 目的

`meta-explain` の理解ゲートを `html` の独立workflowへ吸収し、通常HTML作成とメタ説明を1つのSkill入口から明確に振り分けられる状態にする。

## 現状

1. `html/SKILL.md` は通常HTML作成の役割・出し先・quick/full・作り方を1ファイルに持つ。
2. `meta-explain/SKILL.md` はメタ説明の手順と安全ゲートを持ち、出力規約として `html` を参照する。
3. `meta-explain/references/説明の型.md` はメタ説明固有の見せ方を持つ。
4. `html` と `meta-explain`、catalogには既存の未コミット変更があるため、巻き戻さず現在内容を基準に統合する。

## 方針

1. `html/SKILL.md` を発火条件・workflow振り分け・共通安全方針・1ホップ参照だけを持つrouterへ変更する。
2. 通常HTML作成を `html/workflows/create-html.md`、理解ゲートを `html/workflows/meta-explain.md` へ分離する。
3. メタ説明固有の見せ方を `html/references/meta-explain-layout.md` に置く。
4. 現在の `mobile-preview.md`、`html-structure.md`、quick/full、template、scriptは維持する。
5. 発火・構造テスト後、人間承認を得て旧 `meta-explain` と5本のruntime symlinkを削除する。

## 完了条件（レビュー項目）

- [x] `skills/html/SKILL.md` が70行以内のrouterで、通常HTMLとメタ説明を別workflowへ振り分けている。
- [x] `skills/html/workflows/create-html.md` が通常HTMLの入力・quick/full選択・作成・提示を端から端まで持つ。
- [x] `skills/html/workflows/meta-explain.md` が正本調査・同一HTML更新・合意条件・合意前の編集禁止を持つ。
- [x] `skills/html/references/meta-explain-layout.md` が固定7節型と理解ループの見せ方を持ち、汎用HTML規約を重複定義していない。
- [x] `skills/html/SKILL.md` から全workflow/referenceへ1ホップで到達でき、参照pathが実在する。
- [ ] 通常HTML依頼とメタ説明依頼の発火意図が区別され、軽いすり合わせ・壁打ちを拾わない。
- [x] 既存のmobile preview変更とユーザーの未コミット変更を巻き戻していない。
- [x] `skills/html/SKILL.html` が新構造に合わせて再生成されている。
- [x] 旧 `skills/meta-explain/` と5本のruntime symlinkを、人間承認後に削除し、catalogと削除ログを更新している。
- [ ] 旧Skillが無い新規runtimeで、メタ説明の自然発話が `html` のメタ説明workflowへ発火する。
