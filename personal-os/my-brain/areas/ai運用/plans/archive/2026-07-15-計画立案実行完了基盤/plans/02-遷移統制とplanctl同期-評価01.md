対象計画: 02-遷移統制とplanctl同期.md ／ ラウンド: 01
diff範囲: base 5583899 → head task/pf02=8d7fc3a（2 commits） ／ 規模: フル ／ 評価者: codex read-only reviewer

# 評価01: 遷移統制とplanctl同期（Wave 2）

## 項目別採点   ※ 子計画「完了条件（レビュー項目）」と同順（対象外=他子の所有範囲）

- [PASS] done/archiveの遷移ゲート — active→doneは最終評価全PASS必須、done→archive・非completed archiveは終了記録・人間確認を検証（bucketctl_core.pyの遷移表・evaluation_passes()・archive_errors()）。
- [PASS] 終了区分・completed偽装の検査 — 終了記録.md必須項目、completed時の完了条件・評価・Program子完了をplan-lint経由で検査。
- [PASS] 容量の一元定義 — LIMITS一箇所でactive≤3・paused≤3・done≤8・planning/archive無制限、流入拒否と `check --json`。自動退避・--forceなし。
- [FAIL] planctl同期の維持契約 — `planctl.py` が明示 `plans/` rootを受けず `--repo-root` から親ディレクトリ推測（repo非依存契約に反する）。`changed_paths` は絶対path/`../` 拒否のみで禁止範囲・実commit差分と照合しない。`progress --apply` が対象子以外バイト不変契約に反しProgram先頭の `大幅更新日` を書き換える。`rename --check` が読み取り専用でなく `--date` を必須化し、dry-runで参照追従差分を提示しない。
- [FAIL] テスト網羅 — 既存suite(bucketctl 24・plan-lint 25・progctl 19・program-lint 17)は緑だが、新規test_planctl.shが終了記録なしarchive拒否までしかなく、rename・禁止範囲違反・非completed archive正常/拒否・archive lint・repo-local plans rootの回帰テストが無い。
- [PASS] 変更禁止範囲・対象path限定 — hooks-registry・agents-registry・session-board本体・テンプレ本文・progctl/program-lint実装・既存計画フォルダに不接触。

## 追加指摘（非ブロッキング）

- run manifest生成値と phase語彙は契約どおり。ただしmanifest読込時にphase以外を検証せず、`close` がmanifestを受けず `closed` へ遷移できない。`implemented`/`review_passed`/`blocked` へ進める経路も無い。
- `apply-evaluation` が本文・マップ書換え後にlintし、失敗時ロールバックが無い（非原子的）。
- `git diff --check` 問題なし。レビューによる作業tree変更なし。

## 総合判定

FAILあり（PASS 4・FAIL 2・対象外9）→ 修正01.mdへ。
