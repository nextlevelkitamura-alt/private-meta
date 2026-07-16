対象計画: 05-daily-notion-sync安全回復.md ／ ラウンド: 01
diff範囲: daily-notion-sync の scripts/tests/loop.md ／ 規模: フル ／ 評価者: 独立read-only reviewer

# 評価01: daily-notion-sync の安全回復

## 項目別採点   ※ 子計画「完了条件（レビュー項目）」と同順

- [PASS] `com.kitamura.daily-notion-sync` が停止済みで、停止理由・停止日・再判断期限が記録される。
  根拠: `launchctl print` はservice不存在、`loop.md` と `実行loop一覧.md` は2026-07-14停止・2026-08-13再判断を示す。
- [FAIL] `parse-daily.sh` が現行v3の稼働行と完了行を期待するTSVへ正規化する。
  根拠: `## 終わったこと` のrepo見出しだけ、または子成果のない親タスクをexit 0・0行として受理する。
- [FAIL] 解析不能・入力不整合時は非0で停止し、Notion archiveを呼ばない。
  根拠: repoだけ・親だけ・閉じ記号のない `‹計画: …` マーカーが非0にならず、正常な空データへ寄る。
- [PASS] stub tests、関連shell/Python構文、loops-registry検証、差分整形がPASSする。
  根拠: reviewer再実行で13/13、bash構文、Python compile、`verify.py`、`git diff --check` がPASS。ただし上記FAIL fixtureは未収録。
- [FAIL] 独立read-onlyレビューが全項目をPASSとし、外部操作が未実施である。
  根拠: 外部API・launchd変更は0件だが、入力構造検証にP1 FAILが残る。

## 総合判定

FAILあり。`05-daily-notion-sync安全回復-修正01.md` へ差し戻す。launchd停止は維持し、Notion APIを実行しない。

## 修正指示ドラフト

done parserでrepo・親タスクごとの子成果数を検証し、repo/親の切替時と節末で0件なら非0にする。
計画マーカーは完全な閉じ記号と末尾位置を要求する。回帰fixtureとsession-table直呼びのAPI前停止を追加する。
