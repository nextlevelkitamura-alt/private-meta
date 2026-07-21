# htmlスキルへ実文ウォークスルー部品を追加

- 起票: 2026-07-10（Codexサブエージェント定義書セッションからの派生）
- 対象repo: private-meta（`personal-os/AIエージェント基盤/skills/html/`）
- 規模: ライト（2〜3ファイル・戻せる・人間ゲートなし）
- 実装: sonnet subagent（本計画を読んで実施）

## 背景

- 2026-07-10のCodexサブエージェント定義書で、v1（設定の逐条解説型）よりv2（「実行時に何の文字が流れるか」をsteps＋実文コードブロックで追うウォークスルー型）の方が分かりやすい、と人間が評価した。
- 現テンプレ（`assets/artifact-template.html`）には実文を見せるコードブロック部品が無く、選択ラダー（`references/html-structure.md` §3）にも「流れの再現」の受け皿が無い。
- 参考実物: `/private/tmp/claude-501/-Users-kitamuranaohiro-Private/54420baf-9eac-4afb-9cb1-9702f9737218/scratchpad/codex-subagents-guide.html`（`.steps`＋`.codeblock`の組み合わせ、`.cm`/`.hl`/`.arg`の3色注釈）。

## やること

1. `assets/artifact-template.html`: `.codeblock` 部品を追加する。
   - ダーク地（実文用）・`.cm`（コメント灰）/`.hl`（強調緑）/`.arg`(引数青)の3クラス。
   - 既存部品と同じ様式のCSSコメント（いつ使うか1行）と、`.steps`のstep内に実文を置く使用見本コメントを付ける。
2. `references/html-structure.md` §3 選択ラダー: `.steps` の行の直後に「実行フロー・コマンドや対話のやり取りを再現する → `.steps` の各stepに `.codeblock` で実文（入力・コマンド・出力のサンプル）を入れる（ウォークスルー型）」の行を追加する。
3. `references/html-structure.md` §2（見やすさの基本）に指針を1項目追加: 「仕組み・定義・設定の説明は、逐条解説より『入力→処理→出力』の実文サンプルで追わせる方が伝わる。原文全文が必要な場合は `details` に折りたたみ、ページの主役はウォークスルーにする」。
4. `global-skill-registry/AGENTS.md` を読み、スキル内容変更時の更新義務（catalog等）がある場合のみ、その最小更新を行う。義務が無ければ何もしない。

## やらないこと

- `SKILL.md` の役割・モード構成の再設計
- `about.html` の再生成
- 既存部品の削除・改名・並び替え
- 配色トークンの変更

## 完了条件（レビュー項目・こうなっていれば正しい）

- [x] `artifact-template.html` に `.codeblock` のCSSと使用見本コメントがあり、既存トークン（`--mono` 等）を再利用している。dark分岐（`prefers-color-scheme`/`data-theme`）は追加されていない（部品の地色が暗いのはライト単色方針と矛盾しない）。
- [x] `html-structure.md` §3 にウォークスルー型の行が1本増え、既存項目の番号・フォールバック関係（表→kv→steps→…→deflist）が壊れていない。
- [x] 「実文で見せる・原文はdetailsへ」の指針が§2に1項目だけ追加されている。
- [x] 変更ファイルが `skills/html/` 配下（＋更新義務がある場合の `global-skill-registry/` 最小行）に閉じている。
- [x] パス指定でcommitされている（`git add -A` 不使用・push無し・コミットメッセージに変更理由1行）。

※ 2026-07-21クローズ儀式で見出し・チェックボックス書式へ正規化（文言は不変）。採点は評価01.md（遡及）。

## 戻し方

- commit単位で `git revert`。テンプレ・referenceへの追記のみで既存記述の書き換えは最小のため、衝突リスクは低い。
