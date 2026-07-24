親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 不可 ／ レビュー: Review 1へ集約

# 仕事repo既存計画の正本整理

## 目的

人間が選んだ既存計画を1件ずつ、正しい計画箱に残すか移すかを判定し、参照consumerと同じ波で手書き状態の二重管理を縮小する。

## 現状

legacy計画は、`領域/**/計画/`、`計画一覧.md`、task/eod/review等のSkill、schedule参照に接続している。planだけを移すと、入口と更新先が壊れる。

## 方針

1. 台帳から、外部副作用がなく、consumerが少なく、実状態の根拠が明確な1件を人間が選ぶ。
2. 整理前に、現在path、対象領域/プロジェクト、計画類型、正しい計画箱、更新consumer、移動要否、rollback commitを提示して承認を得る。
3. 領域固有計画が正しい `領域/.../計画/` にある場合は移動せず、format・consumer・索引だけを整理する。repo横断計画の誤配置だけをroot plansへの移動候補にする。
4. 移動が承認された場合だけ、`git mv` と全active consumer参照更新を同一wave・同一commitにする。
5. 旧pathが必要な場合は新正本への1行ポインタだけを置き、本文・状態・次の一手を複製しない。
6. `計画一覧.md` は全consumer切替まで削除しない。残す場合も手書き状態正本ではなく生成・read-only索引へ降格する。
7. 1件の評価と人間確認がPASSするまで2件目を整理しない。成功後も一括移行せず、台帳の優先順で同じ手順を反復する。

## 実行パッケージ

1. **L01 人間選定**: 外部副作用がなく、consumerが少なく、path移動不要を優先した既存plan 1件を選ぶ。
2. **L02 canary整理**: 選択plan、直接consumer、生成indexだけをallowed pathsにし、正しい箱にあれば移動せずmetadata/consumerだけを整える。
3. **L03 review/rollback**: task/eod/review/repo-evalの対象回帰、旧path本文複製0、commit revertを確認し、次の1件へ進むか人間が判断する。

## 直列ゲート

L01→L02→L03は直列。`git mv`、旧path pointer、2件目の開始はそれぞれ別の人間承認とする。

## 完了条件（レビュー項目）

- [ ] 人間承認した既存計画1件だけが整理対象で、正しい計画箱にある場合は移動されていない。
- [ ] 移動した場合はrepo横断計画である根拠と人間承認があり、root `plans/<bucket>/` へだけ移動している。
- [ ] 対象計画のactive consumerが全て正本pathを参照し、索引や旧pathへ状態を書かない。
- [ ] 旧pathに計画本文・状態・次の一手の複製がない。
- [ ] `計画一覧.md` が索引/legacyビューとして明示され、対象計画の状態正本になっていない。
- [ ] task/eod/review/repo-eval等の対象回帰テストがPASSする。
- [ ] 移行commitに無関係なユーザー変更、外部データ変更、別計画の移動が含まれない。
- [ ] commit revertで旧path・consumer・計画状態が一括して事前状態へ戻る。
- [ ] 対象1件の実行証拠がReview 1で全PASSし、人間が次の1件へ進むか判断している。
