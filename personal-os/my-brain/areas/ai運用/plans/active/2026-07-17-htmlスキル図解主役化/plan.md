分類: skill ／ 種別: 既存改善
規模: ライト
形態判定: 単発 ／ 理由: skills/html配下だけで完結し1commitで戻せる文言・雛形改修
並列: 不可 ／ レビュー: 都度

# htmlスキル図解主役化

## 目的

/htmlスキルの出力を「テキスト部品が主役・図解は例外」から「図解＋キャプションが主役・テキストは図で描けない内容だけ」の既定へ変える。フォルダ構成・流れ・関係の説明が、依頼のたびに指示しなくても図で出る状態にする。

## 非対象

- workflow振り分け（create-html / meta-explain / mobile-preview）の構成変更
- quick/full二択の廃止・統合
- 白背景ライト単色ルールの変更（現行維持・図にも適用）
- mermaid等の新しい描画エンジン導入（SVG雛形方式を維持）
- 正本md・デイリー・Notion同期対象の扱いの変更

## 現状

図解が少ない原因はスキル定義側にある（2026-07-17に実ファイル確認・Artifact「htmlスキル 図解強化の修正計画 v2」で人間合意済み）。

1. `references/html-structure.md` §3の選択ラダーは「上から判定して最初に当たった部品を使う」形式で、表・kv・steps・tree・compare2・deflistが上位、SVG図は8段目の併用扱い。判定が図に到達しない。§3-5でフォルダ構成はテキストの `.tree` に割り当てられている。
2. `references/mode-quick.md` §2に「図とインタラクションは基本入れない」とあり、「迷ったらquick」規約と合わさって大半の出力が図なしになる。
3. `assets/artifact-template.html` の部品は全てテキスト系で、SVG図（ノード・矢印・ツリー・レイヤー）の雛形が無い。ゼロから描くコストを避けてテキストに逃げる。
4. 見せ方マッピングは `references/meta-explain-layout.md` §3にのみ存在し、通常HTML経路（create-html）に図解の対応表が無い。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private（private-meta）
- 実行形: direct
- 最初に読む順番:
  1. /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md
  2. この計画
  3. /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/html/ 配下の現行ファイル一式
- 依存成果: 設計合意済みArtifact「htmlスキル 図解強化の修正計画 v2」（2026-07-17・レシピ6種・既定レイアウト・ルール文言の方針）
- 変更可能範囲: personal-os/AIエージェント基盤/skills/html/ の SKILL.md・SKILL.html・references/・assets/artifact-template.html
- 変更禁止範囲: skills/html/workflows/mobile-preview.md と scripts/（今回の対象外）、runtime露出symlink（既存露出のまま・新規露出はしない）、他Skill・registry
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 白背景ライト単色（dark分岐禁止）／self-contained・JSなし／部品CSSと雛形実体の正本はartifact-template.htmlのみ（md側へSVG本文を複製しない）
- 検証: 実題材（AIエージェント基盤のフォルダ構成説明）でquick/full各1枚を生成し、完了条件のレビュー項目で採点する
- 停止・エスカレーション条件: 変更が宣言7ファイルを超える／既存workflowの構成変更が必要になる／白背景規約と衝突する場合は停止して人間確認
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

図解を条件付き部品から**ページの既定**へ格上げする。縛りは目安に留め、逃げ道を明記する（決めすぎない・人間合意済み）。変更は新設1・改訂5・再生成1の7ファイル。

1. **新設** `references/diagram-recipes.md`（本丸）: 「この内容ならこの図」の対応表とレシピ6種の使い所。
   - ボックス型ツリー図（フォルダ構成・正本とruntime露出。symlinkは破線）
   - 横フロー図（手順・パイプライン。人間ゲートは琥珀で強調）
   - 関係図（依存・参照。矢印の向き＝参照の向き）
   - レイヤー図（層構造。触る層だけ着色）
   - before/after対比図（同じ図法で並べ差分だけ着色）
   - タイムライン（経緯。現在地を塗りで示す）
   - 図中の文字量の上限と色の意味割当（推奨=緑・注意=琥珀・強調1色）も規定する。
2. **改訂** `assets/artifact-template.html`: 図解部品CSS（.fig/.figcap等）とレシピ6種のSVG雛形実体を追加。実体はここだけに置く。
3. **改訂** `references/html-structure.md`: §3ラダーの1段目に「主題が構造・流れ・関係・層・差分・経緯なら図が主役（diagram-recipes.mdで選ぶ）」を追加し、テキスト部品ラダーをその後の受け皿へ。§3-5のフォルダ構成をボックス型ツリー図へ変更（.treeはdetails内の補足用へ降格）。§5節の型を「リード1行→図＋キャプション→補足」既定へ更新。
4. **改訂** `references/mode-quick.md`: 「図とインタラクションは基本入れない」を削除し、「構造・流れ・関係が主題なら雛形ベースの図を既定で1〜2枚。凝った描き起こしはfullのみ。装飾目的の図は禁止」へ。
5. **改訂** `references/mode-full.md`: 固定構造の全体図1枚は維持しつつ、目安「主要節の過半で図が主役・1ページ最低1枚」を追記。公開前チェックに「構造・関係を扱う節が文章だけになっていないか」を追加。
6. **改訂** `references/meta-explain-layout.md` §3: 見せ方マッピングをdiagram-recipes.mdのレシピ名参照へ付け替え（二重管理解消）。
7. **改訂＋再生成** `SKILL.md` §4にレシピ集を追記し、`SKILL.html` を再生成。

ルール文言の書き分け（合意済み）: 既定=「各節でまず図で描けるかを判定」／目安=「主要節の過半で図が主役・1ページ最低1枚」（厳格比率ルールにしない）／例外=「長い理由・逐条規約・列挙可能な事実はテキスト部品でよい。装飾だけの図は逆に禁止」。

## 完了条件（レビュー項目）

- [ ] `references/diagram-recipes.md` が存在し、6レシピすべてに「使い所」と「テンプレ内雛形への参照」があり、SVGコード本文を複製していない
- [ ] `assets/artifact-template.html` に図解部品CSSと6レシピのSVG雛形実体があり、dark分岐・暗色背景が無い
- [ ] `references/html-structure.md` §3の1段目が図解判定になっており、フォルダ構成の割当がボックス型ツリー図（.treeは補足用）へ変わっている
- [ ] `references/html-structure.md` §5の節の型が「リード1行→図＋キャプション→補足」を既定として含む
- [ ] `references/mode-quick.md` に「図とインタラクションは基本入れない」が残っておらず、雛形ベースの図既定（1〜2枚・装飾禁止）が書かれている
- [ ] `references/mode-full.md` に目安「主要節の過半で図が主役・1ページ最低1枚」と公開前チェックの追加項がある
- [ ] `references/meta-explain-layout.md` §3がdiagram-recipes.mdのレシピ名を参照し、図法の定義本文を複製していない
- [ ] `SKILL.md` §4にdiagram-recipes.mdが追記され、`SKILL.html` が再生成されている
- [ ] 実題材（AIエージェント基盤のフォルダ構成説明）のquick生成で図が1枚以上主役になり、full生成で主要節の過半が図主役になる
- [ ] 全変更が skills/html/ 配下に収まり、workflows/mobile-preview.md・scripts/・runtime露出symlinkに変更が無い

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
