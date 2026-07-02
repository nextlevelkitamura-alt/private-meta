分類: repo ／ 種別: 既存改善 ／ 優先: ○
次: job-create の data/ を正本化（旧ダッシュボードから移記 2026-07-02）

# 求人立案引き継ぎ基盤

## 目的

1. 求人立案を、チャットをまたいでも迷わず再開できる運用にする。
2. 人間が見る判断資料（月次計画）と、AI/Playwrightが読む実行データを分ける。
3. 月の正本を一つにして、毎回ゼロから作り直さない。
4. 他チャットでスプシ更新や企画をしても、痕跡が必ず残る形にする。

## 背景

5. 仕事repo `scripts/job-create/` に求人立案自動化がある。
6. `scripts/job-create/data/` に現在値・過去バッチ・巡回状態・エラーHTML・`.bak` が約90ファイル混在し、正本が埋もれている。
7. 他チャットのスプシ更新・企画は repo に痕跡が残らず、次チャットで再開できない。

## 方針（軽量版・確定）

8. 月＝正本の単位。日付フォルダ・runフォルダ・証跡フォルダは作らない。
9. 求人立案の月別正本は `求人管理/求人立案/YYYY-MM/` に置き、中身は3つだけにする。
10. `data/` は消さず凍結し、jobs/prompts/created の正本は月フォルダ側へ移す。
11. 証跡（ログ・スクショ・エラーHTML）は `scripts/job-create/` 側に残し、人間の見る場所に混ぜない。
12. 新Skill・新workflowは作らない。既存workflowの完了Stepと出力先の変更で足りる。

## フォルダ構成

```text
求人管理/
  README.md                      # 求人管理全体の入口
  求人立案/
    README.md                    # 立案の正本ルール
    YYYY-MM/
      月次計画.md                 # 現在地＋対象一覧＋企画・保留（人間が開く1枚）
      スプシ更新ログ.md           # スプシを触ったら1行（他チャット引き継ぎの要）
      実行データ/                 # jobs.json / prompts.json / created.json（AIが読む）
```

- `scripts/job-create/data/` ＝ 凍結した旧作業履歴（追記禁止・正本でない）。
- `scripts/job-create/output/`・`data/` ＝ 証跡（ログ・スクショ・エラーHTML）。障害時だけ見る。

## 役割と分離

13. 月次計画.md＝計画＋現在状態。冒頭に「状態／最終アクション／次アクション／対象シート」を置く。
14. スプシ更新ログ.md＝履歴。日時・チャット・シート・行・列・内容を1行で追記。
15. 実行データ/＝機械データ。手で読む正本ではない。scriptsの読み書き先。
16. 人間は月次計画.mdとスプシ更新ログ.mdの2枚を追えばよく、AIは実行データ/を読む。

## 実装スコープ

### A. docs（仕事repo・コード無し）

17. `仕事/AGENTS.md` に求人立案の正本導線と `data/` 凍結を2行追記。
18. `求人管理/README.md` を軽量版に書き換え。
19. `求人管理/求人立案/README.md` を軽量版に書き換え。
20. `scripts/job-create/data/README.md` を新設し、凍結宣言を書く。
21. `求人管理/求人立案/2026-07/` に 月次計画.md・スプシ更新ログ.md・実行データ/ の雛形を置く。

### B. Skill（仕事repo・新workflow作らない）

22. `SKILL.md` の安全/完了ルールに、出力先＝実行データ/、スプシ操作後＝スプシ更新ログ.md 1行 を追記。
23. `workflows/求人作成.md` に「① 月次計画.mdの現在地を読む」入口Stepを追加。
24. prepare/create-jobs の出力先記述を `実行データ/` に更新。
25. Step10 完了チェックに「現在地ヘッダ更新」「スプシ更新ログ記入確認」を追加。

### C. CLI（仕事repo・唯一のコード改修）

26. `config.ts` に `--month` から出力先を解決する `runDataDir(month)` を追加（未指定は `data/` フォールバック）。
27. `prepare` は `--month`（または `--out-dir`）で `実行データ/jobs.json`・`prompts.json` に出す。
28. `create-jobs` は `--month` で `実行データ/jobs.json` を読み、`実行データ/created.json` に出す。月側が無ければ `data/` にフォールバック。
29. エラーHTML等の一時出力は `data/` のままにし、created.json の正本だけ月側へ移す。
30. `plan-month --apply` は今回スコープ外（Phase 2 残）。create経路（prepare/create-jobs）を優先。

### D. plan（personal-os repo）

31. この plan.md を軽量版に更新し、完了後に結果と反映先を追記。

## 他チャット引き継ぎの最小ルール

32. 月次計画.md 冒頭に現在地（状態／最終アクション／次アクション）を必ず置く。
33. スプシを触ったら スプシ更新ログ.md に1行追記する。
34. 新チャットは「月次計画.md の現在地 → スプシ更新ログ.md」を読めば再開できる。

## 受け入れ条件

35. 別チャットでも `求人管理/求人立案/YYYY-MM/月次計画.md` を読めば現在地が分かる。
36. `prepare --month` / `create-jobs --month` の出力が `実行データ/` に落ちる。
37. `data/` を巻き戻さず、正本でないことが README で明確。
38. 既存コマンドが `--month` 無しでも従来どおり `data/` で動く。
39. 既存の未コミット変更（current-jobs.json 等）を巻き戻さない。

## 優先順位

40. Phase 1: A（docs）＋ B（Skill）。コードほぼ無しで引き継ぎが立つ。
41. Phase 2: C（CLI出力先）。出力が自動で月フォルダへ。
42. Phase 3（任意）: スプシ更新ログ自動追記、audit、jobs.json スキーマ拡張、plan-month 移行。

## リスク

43. create-jobs は登録本体。変更は入力解決＋created.json出力先の最小限に留める。
44. 出力先を半移行のまま放置しない。`--month` を渡す前提を Skill workflow に明記する。
45. 証跡を月フォルダへ動かさない（人間の見る場所を汚さない）。

## 結果と反映先

2026-06-29 Phase 1+2 実装（仕事repo, branch master, 未コミット）。

- docs: `仕事/AGENTS.md`（求人立案導線）、`求人管理/README.md`、`求人管理/求人立案/README.md` を軽量版に更新。`scripts/job-create/data/README.md`（凍結宣言）新設。`求人管理/求人立案/2026-07/` に 月次計画.md・スプシ更新ログ.md・実行データ/ の雛形作成。
- Skill: `.agents/skills/job-create-flow/SKILL.md` に「出力先と引き継ぎ」節を追加。`workflows/求人作成.md` に入口Step0（現在地読込）、create-jobs出力先記述、Step10完了確認2項を追加。
- CLI: `config.ts` に `WORK_REPO_ROOT`・`jobCreateMonthDir`・`runDataDir` を追加。`prepare.ts` は `--month`/`--out-dir` で `実行データ/` 出力。`create-jobs.ts` は `--month` で `実行データ/jobs.json` 入力・`実行データ/created.json` 出力、月側不在時は `data/` フォールバック＋警告。エラーHTML等の証跡は `data/` のまま。
- 検証: `tsc --noEmit` で新規型エラーなし（既存のPlaywright型不整合・check-wageのみ）。ユニットテスト20件pass。`runDataDir('2026-07')` が月フォルダ、未指定が `data/` を返すことをランタイム確認。
- 残: plan-month の出力先移行、スプシ更新ログ自動追記、audit、jobs.jsonスキーマ拡張（Phase 3）。
- 未コミット（コミットは未実施）。
</content>
</invoke>
