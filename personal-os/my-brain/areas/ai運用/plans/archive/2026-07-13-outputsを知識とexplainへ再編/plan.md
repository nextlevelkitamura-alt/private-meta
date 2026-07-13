分類: 横断 ／ 種別: 統合整理
規模: フル
優先: ○

# outputsを知識とexplainへ再編

## 目的

ai運用 の `outputs/` が混在させている「恒久知識(md)」と「使い捨ての人間向けrender(HTML)」を、保存先の規約ごと分離する。あわせてHTMLスキルが定義していない**ディスク保存先の空白**を埋め、`outputs/` と `plans/` 内にHTMLが二重に散らばる構造をなくす。

## 現状

1. area標準(`../../AGENTS.md` §1)は `AGENTS.md/CLAUDE.md/identity.md/plans/` の4点。`outputs/` は ai運用 だけの非標準な5点目で、他areaに無い。
2. `outputs/2026-07/` の5枚は種類が混在: 使い捨て単発レポート(session-boardフック注入内容 等)と、やや恒久的な提案(loopレジストリ統治案 等)。
3. `plans/active/*/` にもHTMLが4枚散在(`program.html`・`セッション宣言型ボード計画.html`・`Orcaコックピットと指揮系統の構造.html`・`areas運用の現状調査と縮小設計.html`)。命名はbasename一致/不一致が混在。
4. 正本規約が2本あって食い違う: `GLOBAL_AGENTS.md` §3(md説明HTMLは同じ場所・同じbasename)と §4(生成成果物は `outputs/YYYY-MM/`・最終物git追跡)。どちらを使うか計画側から一意に決まらない。
5. HTMLスキル(`skills/html/workflows/create-html.md`・`meta-explain.md`)はディスク保存先を定義せず、既定Artifact・ローカルは「リンク提示」のみ。保存の度にAIが置き場所を即興している(3の散らばりの根本原因)。
6. 2026-07-13 決定ログ#15で `outputs/` をgit追跡化済み(外出先pullでモバイル参照する動機)。HTMLはObsidianモバイルで開けず、mdはそのまま読める非対称がある。

## 方針

採用形: **top-level `知識/`(md)＋ 計画ごと `explain/`(HTML)**(2026-07-13 ユーザー選択)。

1. **知識(md)**: area直下に `知識/` を新設。**完成した恒久・再利用可能な参照md のみ**を置く(モバイルでそのまま読める)。ガードレール — 未確定の考え・調査は従来どおり `identity.md` か plan の `方針` に置き、`知識/` に入れない。特定計画にしか使わない知識はその計画内(`plan.md`/`references/`)。=`知識/` を旧 `thinking/` の再来にしない。
2. **explain(HTML)**: 計画に紐づく人間向けHTMLは `plans/<バケット>/<計画>/explain/*.html` に置く。`meta-explain` ワークフローの正式な出力先にする。program の `plans/`・`references/` と同列のサブ構造。名称は `explain/` を既定にする(meta-explain語彙と整合。`説明/` でも可だが1つに固定)。
3. **計画に紐づかないHTML**: 原則md化して `知識/` へ。render目的でHTMLが要る時だけ、その知識mdの隣に §3 のbasename規約で `知識/<name>.html` を置く。
4. **保存先の空白を埋める**: `skills/html/` の該当workflowに「ディスク保存先は `GLOBAL_AGENTS.md` §4 と本方針(explain/・知識/の振り分け)を正本参照」の導線を1行足す(規約本文はコピーしない=契約§8)。実装は実装正本 `AIエージェント基盤/skills/html/` で行い、本areaに本文を持たない。
5. **正本追従**: `../../AGENTS.md` §1(area標準に `知識/` と `plans/<計画>/explain/` を明記) と `GLOBAL_AGENTS.md` §3/§4(explain/サブフォルダ許容・md/HTML/知識の適用境界)を同じ作業で改定。決定ログに1件残す(規約変更=契約§8)。
6. **既存物の移設**: `outputs/` の5枚と `plans/` 内4枚を上の規約先へ `git mv`。使い捨てで残す価値の無いものは破棄をユーザーに確認。`.gitignore` の ai運用 ブロックを新構成(`知識/**` 許可・`outputs/**` 許可行の除去/置換)に追従。
7. **横展開**: ai運用 単発にせず area標準として決め、work/money/health の同型 `.gitignore` ブロックと構成にも反映する(決定ログ#15 の未対応分を回収)。範囲が大きければ別計画へ切り出す。
8. **人間ゲート**: 実ファイル移動・正本改定・削除・symlink変更は人間承認後に実施。本計画ドラフトの段階では実施しない。
9. **履歴の扱い**: archive/done の過去計画・決定ログにある `outputs/` 表記は当時の事実として残す。除去対象は、現在の保存規約・実ファイル・運用導線だけとする。

## 完了条件（レビュー項目）

- [x] `../../AGENTS.md` §1 のarea標準に `知識/`(md恒久知識) と `plans/<計画>/explain/`(人間向けHTML) が明記され、`知識/` の「置くもの/置かないもの」(未確定の考えはidentity.md/方針へ)が書かれている。
- [x] `GLOBAL_AGENTS.md` §3 が計画内 `explain/` サブフォルダを許容し、§3(md隣接HTML)と §4(outputs成果物)の適用境界が矛盾なく1つに統合されている。
- [x] `AIエージェント基盤/skills/html/` の create-html / meta-explain に、ディスク保存先を §4＋本方針へ委譲する導線が1ホップで足されている(規約本文の複製が無い)。
- [x] ai運用 直下の可視エントリが area標準＋`知識/`＋`決定ログ.md` に収束し、`outputs/` が消えている。
- [x] `outputs/2026-07/` の旧5枚が、対応計画の `explain/` か `知識/`(md化) へ移設され、現在の保存規約・実ファイル・運用導線に旧 `outputs/` パス参照が残っていない。
- [x] `plans/active/*/` の散在HTML4枚が各計画の `explain/` に移設され、命名が統一されている。
- [x] `.gitignore` の ai運用 ブロックが `知識/**` と `plans/**`(explain含む)を許可し、旧 `outputs/**` 許可行が新構成に追従している。
- [x] work/money/health に同じ標準と `.gitignore` 許可が反映されている。
- [x] 2026-07-13 決定ログに、規約変更(area標準・§3/§4・保存先)の1ブロックが追記されている。
- [x] secret混入なし・正本本文の二重管理なし。

## 実装結果

1. `ai運用/outputs/` を削除し、外出先フォルダ参照の2件は `知識/` の同名md＋HTMLへ、残る3件は対応計画の `explain/` へ移設した。
2. 計画直下に散在していた4件も `explain/` へ移設し、`plan.md` / `program.md` の説明は `plan.html` / `program.html` に統一した。
3. area標準・各area入口・`.gitignore`・GLOBAL_AGENTS・html Skill workflowを新しい保存先へ同期し、html Skillの `SKILL.html` を再生成した。

## レビュー方法

- 実装とは別のレビュー担当が上のレビュー項目と、旧 `outputs/` の現行導線不在・HTML保存先・`.gitignore`許可を採点して `評価01.md` に記録する。
- `/root/outputs_review` の独立レビューは、指摘2点の修正・再確認を経て `評価01.md` 全PASSとなった。
