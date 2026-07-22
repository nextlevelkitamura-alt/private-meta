分類: skill ／ 種別: 統合整理
大幅更新日: 2026-07-22
規模: ライト
形態判定: 単発 ／ 理由: skills/html配下＋catalog1ブロックで完結し1commitで戻せる統合改修
並列: 不可 ／ レビュー: 都度

# htmlスキル一本化

## 目的

/htmlのquick/full二択と、合言葉が要るmeta-explain workflowを廃止し、どの依頼（説明・レポート・調査まとめ・比較・ダッシュボード・実装説明）でも同じ「サンドイッチ構造」（結論→先に質問→図解中心の説明→推奨つき再質問）1本で作る形へ統合する。読者想定を「コーディングしないがGO/NGを判断する人」に固定し、3点セット・「つまり」1行訳・用語のその場言い換えを既定にする。

## 非対象

- 白背景ライト単色ルールの変更（現行維持）
- 図解レシピR1〜R6の内容・部品CSS・artifact-template.htmlのCSSと雛形実体の変更（冒頭コメントの更新のみ）
- workflows/mobile-preview.md・scripts/ の変更
- runtime露出symlinkの変更（skillフォルダ名は不変のため不要）
- naiyou-suriawase / grill-me との役割分担の変更
- about.html の扱い（SKILL.htmlと役割重複の疑い。削除は別途人間承認を得てから）

## 現状

- `SKILL.md` §1が3経路（create-html内のquick/full二択・合言葉ゲート付きmeta-explain・mobile-preview）に振り分けている。
- 「迷ったらquick」規約により出力が軽量側へ倒れ、見づらさの温床になっている（2026-07-22人間指摘）。
- 実装説明に必要な型（現状→変更→本文→未決）は `meta-explain-layout.md` に実装済みだが、合言葉を言わないと使われない。
- 設計はArtifact「htmlスキル整理案 v3」（2026-07-22）で合意済み。Q1（サンドイッチ型を基準化）・Q2（実装説明の3点セット必須）・Q3（削除4件を含む本体書き換え）すべて人間承認済み。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private（private-meta）
- 実行形: direct
- 最初に読む順番:
  1. /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md
  2. この計画
  3. /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/html/ 配下の現行ファイル一式
- 依存成果: 合意済みArtifact「htmlスキル整理案 v3」（2026-07-22・Q1/Q2/Q3承認）
- 変更可能範囲: `personal-os/AIエージェント基盤/skills/html/SKILL.md`・`SKILL.html`・`workflows/create-html.md`・`references/`（impl-explain.md新設含む）・`assets/artifact-template.html`（冒頭コメントのみ）・`global-skill-registry/catalog/applied.md`（htmlブロックのみ）
- 削除（2026-07-22人間承認済み）: `workflows/meta-explain.md`・`references/mode-quick.md`・`references/mode-full.md`・`references/meta-explain-layout.md`
- 変更禁止範囲: `workflows/mobile-preview.md`・`scripts/`・他Skill・logs・runtime露出symlink・about.html
- 維持する契約: 白背景ライト単色（dark分岐禁止）／self-contained・JSなし／部品CSSと雛形実体の正本はartifact-template.htmlのみ
- 検証: 完了条件のレビュー項目で評価01.mdを採点する
- 停止・エスカレーション条件: 宣言ファイル外の変更が必要になったら停止して人間確認

## 方針

1. `SKILL.md`: 3経路の振り分けを1本道（create-html）へ。frontmatter descriptionも統一型の文言へ更新する。
2. `workflows/create-html.md`: quick/full選択を廃止。サンドイッチ構造の適用手順＋実装説明時のimpl-explain必須参照＋公開前チェック（旧mode-fullから移設・「つまり」1行等を追加）へ統一する。
3. `references/impl-explain.md` 新設: 3点セット（どこを触る/こう変わる/中身の意味）＋理解ループ（旧meta-explainの合意ゲート・同一URL vN更新）＋根拠と選択肢の書き方。
4. `references/html-structure.md`: 冒頭に読者想定（§1）とサンドイッチ構造（§2）を新設し、旧§1〜9を§3〜11へ再番号。読みやすさルール（用語その場訳・「つまり」1行・1項目2行まで）を追加。モード参照を除去し、恒久HTML追従3方式を旧mode-fullから§11へ移設する。
5. `references/diagram-recipes.md`: quick/full文言の除去と、html-structure.md再番号・impl-explain参照への付け替え。
6. `assets/artifact-template.html`: 冒頭コメントの構造説明をサンドイッチ構造へ更新（CSS・雛形実体は不変）。
7. 削除4件を実施し、`SKILL.html` を新構成で再生成、`catalog/applied.md` のhtmlブロックを更新する。

## 完了条件（レビュー項目）

- [ ] `SKILL.md` にquick/full・meta-explainが経路として残っておらず、workflowはcreate-html＋mobile-previewのみ
- [ ] `references/impl-explain.md` が存在し、3点セット・理解ループ（合意まで対象を編集しない・同一HTMLのvN更新）・根拠の書き方を含む
- [ ] `references/html-structure.md` に読者想定・サンドイッチ構造・読みやすさルール（用語その場訳・「つまり」1行・1項目2行まで）があり、mode-quick/mode-full/meta-explain-layoutへの参照が無い
- [ ] `workflows/create-html.md` にモード選択が無く、実装説明時のimpl-explain必須と公開前チェックがある
- [ ] `mode-quick.md`・`mode-full.md`・`meta-explain.md`・`meta-explain-layout.md` が存在しない
- [ ] skills/html配下の残ファイル（__pycache__除く）に削除4ファイルへの参照が残っていない
- [ ] `catalog/applied.md` のhtmlブロックが1本化・サンドイッチ構造・理解ループ内蔵を反映している
- [ ] `SKILL.html` が新構成で再生成されている
- [ ] 白背景ライト単色・self-contained・JSなしの契約文言が残ファイルで維持されている
- [ ] 変更が宣言範囲（skills/html/＋catalog/applied.md＋この計画）に収まっている

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
