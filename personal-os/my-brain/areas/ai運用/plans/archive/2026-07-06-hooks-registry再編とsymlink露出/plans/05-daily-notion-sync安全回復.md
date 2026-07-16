親計画: ../program.md ／ 分類: loop ／ 種別: 既存改善
並列: 不可 ／ レビュー: 都度

# daily-notion-sync の安全回復

## 目的

現行session-board v3の入れ子行を正しく解析し、Notionの既存行を「0件」と誤認してarchiveしない状態で、
人間確認後にだけdaily-notion-syncを復帰できるようにする。

## 現状

- `parse-daily.sh` は旧フラット形式だけを抽出する一方、`shared/session-board/md/store.py` はv3の
  `- 状態 時刻 | 目標 | 今:…` 形式を出力する。現行行が0件として扱われる。
- `session-table.sh` は日付別DBという前提で0件archiveガードを撤去済みであり、解析失敗時に既存Notion行を
  archiveし得る。`tests/run-tests.sh` のt4/t8も旧契約と食い違い、9 PASS / 2 FAILである。
- `com.kitamura.daily-notion-sync` は30秒間隔で登録済み。元の設計計画は
  `plans/paused/2026-07-06-デイリーNotion表反映/plan.md` に残るが、現在のP0修正の正本は本子計画とする。

## 方針

1. 先に `launchctl print` で登録状態を確認し、`bootout` でloopを停止する。Notion APIを手動実行しない。
   `loop.md` と実行loop一覧を停止状態・理由・再判断期限（停止日から30日以内）へ更新する。
2. `parse-daily.sh` を現行v3の「動いているエージェント」行と「終わったこと」節の双方に対応させ、
   抽出不能・形式不明を空データ成功として扱わない。archive処理へ進む前に、解析失敗を非0で止める。
3. t4をv3 fixtureに対する解析契約、t8を現行archive方針に対する安全契約へ更新する。Notion呼び出しは既存stubだけを
   用い、実際のcredentialやAPIへは接続しない。
4. 実装者と別のreviewerが、v3解析・解析不能時のfail-closed・archive保護・全テストをread-onlyで確認する。
5. reviewerが全PASSでもlaunchdを復帰しない。人間が結果を確認して明示承認した時だけ、手動dry-runと実機復帰を別途行う。

## 完了条件（レビュー項目）

- [ ] `com.kitamura.daily-notion-sync` が停止済みで、`loop.md` と実行loop一覧に停止理由・停止日・再判断期限が記録される。
- [ ] `parse-daily.sh` が現行v3の稼働行と完了行を期待するTSVへ正規化し、旧形式のみへの依存がない。
- [ ] 解析不能・入力不整合時は非0で停止し、Notion archiveを呼ばないことがstub testで確認できる。
- [ ] `tests/run-tests.sh` の全テスト、関連shell構文、`loops-registry/verify.py`、`git diff --check` がPASSする。
- [ ] 独立read-onlyレビューが全項目をPASSとし、Notion API実行・launchd復帰が未実施であることを確認する。
- [ ] <検証可能なチェック>
