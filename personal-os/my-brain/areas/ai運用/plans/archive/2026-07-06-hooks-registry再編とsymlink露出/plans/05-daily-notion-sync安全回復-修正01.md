出所評価: 05-daily-notion-sync安全回復-評価01.md ／ ラウンド: 01 ／ 宛先: daily-notion-sync実装担当

# 修正01: daily-notion-sync の安全回復

※ 口頭要約で渡さず、実装担当にはこのファイルを読ませる。

## 修正項目

### 壊れた完了入れ子を正常0件として受理しない

- 対象: `loops-registry/loops/daily-notion-sync/scripts/parse-daily.sh` のdone parser。
- 今の状態: repo見出しだけ、または子成果のない親タスクをexit 0・0行として受理する。
- 期待する状態: repoには最低1親、各親には最低1子成果が必要で、切替時・節末に不足があれば非0終了する。
- 修正方法の指定: repo/parentごとのchild countを持ち、次のrepo、次のparent、次の節、EOFへ進む前に検証する。
- やらないこと: 正しい空節、デイリーファイル未生成、既存の稼働行/完了行TSV形式を変えない。

### 壊れた計画マーカーを受理しない

- 対象: `parse-daily.sh` の親タスク名から `‹計画: …›` を分離する処理。
- 今の状態: 閉じ `›` がないマーカーや後続文字をstripし、通常の親名として受理できる。
- 期待する状態: マーカーは完全な `‹計画: …›` が親行末にある時だけ許可し、開始記号だけ・閉じ欠落・後続文字ありは非0になる。
- 修正方法の指定: 親行全体を完全一致で検査してから親名と計画pathを分離し、不完全マーカーを明示的に拒否する。
- やらないこと: 正常な計画マーカーのキー除外仕様を撤回しない。

### 回帰fixtureとAPI前停止を追加する

- 対象: `tests/run-tests.sh` の入力不整合テストとsession-table直呼びテスト。
- 今の状態: 未知session行のsync停止は検証するが、repoだけ・親だけ・壊れた計画マーカー、session-table直呼びを覆わない。
- 期待する状態: 4ケースすべて非0になり、Notion stubログ・signatureが作られず、security/curlより前に停止する。
- 修正方法の指定: t12へ3種のdone fixtureを追加し、t13または新規testでsession-table直呼び解析失敗のstub未呼び出しを確認する。
- やらないこと: 実Notion API、Keychain、credential、launchdを使わない。

## 完了の確認方法

修正後、全stub tests、bash構文、関連Python compile、`loops-registry/verify.py`、`git diff --check` を再実行する。
同じread-only reviewerが評価02で、repo/親/計画マーカーの各fixtureとAPI前停止を再確認する。
