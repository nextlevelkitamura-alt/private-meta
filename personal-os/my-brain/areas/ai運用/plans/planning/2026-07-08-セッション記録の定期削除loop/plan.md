分類: loop ／ 種別: 新規作成
規模: ライト
形態判定: 単発 ／ 理由: 単一loop（session-record-prune）の新設で、所有範囲はloops-registry配下1件・rollback単位もそのloop一式に閉じる
並列: 不可 ／ レビュー: 都度

# セッション記録の定期削除loop

## 目的

Claude / Codex のセッション記録（`.jsonl`）の肥大を、一定期間より古いものを定期削除して抑える。
内蔵ディスク逼迫（95%使用・残11GB）と、それに伴う「外付けSSDへ退避したい」誘惑（＝W4評価の
指摘②が現実化する経路）を根から断つ。

## 非対象

- `~/.codex/sessions`・`~/.claude/projects` **以外**のディレクトリ・ファイルへの削除操作
- 保持日数（30日）**以内**のファイルの削除
- 初回dry-runを経ない本番一括有効化
- launchdの自動ロード・有効化（人間ゲート。本計画は実装までを範囲とする）

## 現状（2026-07-08 実測）

- `~/.codex/sessions` 4.0G・うち **30日超＝188ファイル**。`~/.claude/projects` 317M・30日超＝10ファイル。
- 直近7日の Codex 記録は 80ファイル（これは残す範囲）。
- session-board の生存判定は**直近30分の mtime しか見ない** → 古い記録は判定に不要（消しても board は無傷）。
- 定期削除の仕組みは無い。手動放置で膨張し続ける。

## 実行契約

- 対象repo: `~/Private`（private-meta。loop実装は `personal-os/AIエージェント基盤/loops-registry/` 配下に置く既存パターンに従う）
- 実行形: direct（単一loopの新設・所有範囲が小さく指揮官が直接実装する規模）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/loops-registry/AGENTS.md`（loopの正本契約・命名・登録規約）
  2. この計画
  3. 雛形 `loops-registry/loops/board-reconcile/`（plist・scripts・loop.mdの型）
- 依存成果: なし（W4評価の指摘②を引き金とした独立loop。他子計画の成果に依存しない）
- 変更可能範囲: `personal-os/AIエージェント基盤/loops-registry/loops/session-record-prune/` 配下（`scripts/`・`*.plist`・`loop.md`・`tests/`・`output/logs/`）
- 変更禁止範囲: `~/.codex/sessions`・`~/.claude/projects` 以外のディレクトリへの削除操作、launchdへの自動ロード・有効化（人間ゲート）、session-boardの生存判定ロジック本体
- ファイル担当マップ: 不要（delegated-parallelではない）
- worktree方針: 不要（対象repo内で直接commitする小規模loop実装）
- 維持する契約: session-boardの生存判定（直近30分のmtimeしか見ない）を壊さない。対象2ディレクトリ以外に一切触れない。ログは件数・解放容量のみでsecret・記録の中身を出さない。
- 検証: `tests/test_prune.py` 全緑（11本）＋ 初回dry-runログで解放対象件数・容量を確認（実ファイルは不変のまま）
- 停止・エスカレーション条件: 保持日数以内のファイルが削除候補に含まれる場合、対象2ディレクトリ以外に触れる操作が発生する場合は実装を止めて人間へ報告する
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. **新loop**（`board-reconcile` を雛形に）: `loops-registry/loops/session-record-prune/` を新設。
   launchd 日次相当（`board-reconcile` の plist を踏襲＝zsh入口→scripts）。
2. **対象**: `~/.codex/sessions`・`~/.claude/projects` 配下の `*.jsonl` で `mtime > 保持日数`。
   保持日数＝**30日**（人間裁定 2026-07-08。board生存判定は直近30分しか見ないため十分安全）。
   対象2ディレクトリ**以外は絶対に触らない**。
3. **安全ガード**（削除は不可逆なので厚めに）:
   - 方式＝**`~/.Trash` へ移動**（人間裁定 2026-07-08。即 `rm` にせず復旧余地を残す。Trash は OS が後で空にする）。
   - 初回は **dry-run 既定**（動かさず「移す予定」をログ）→ 人間がログ確認 → 本番を有効化。
   - 保持日数**以内**（30日）の新しいファイルは絶対に動かさない（テスト＋dry-runで担保）。
   - ログは**件数・解放容量のみ**（記録の中身・secret は出さない）。
   - launchd ロードは**人間ゲート**（session-board の包括承認には含まれない別loop）。
4. **言語**（フック言語規約に準拠）: 削除ロジック＋ガードは `scripts/prune.py`（Python）。launchd 入口は
   `cd` して呼ぶ薄い `.sh`。

## 完了条件（レビュー項目）

- [ ] 保持日数**以内**の `.jsonl` は1つも消えない（Python テスト＋初回 dry-run ログで確認）
- [ ] 対象2ディレクトリ**以外**のファイルに一切触れない（パス固定・テストで確認）
- [ ] ログに解放容量・件数が出て、記録の中身や secret は出ない
- [ ] 初回は dry-run → 人間確認 → 本番有効化の順（launchd 載せは人間ゲート）
- [ ] session-board の生存判定が壊れない（直近は残る＝board テスト緑のまま）
- [ ] loop 一覧（`loops-registry/実行一覧/personal-os.md`）に稼働状態が記録される

## 未確定の論点（着手前に決める＝人間判断）

- **頻度**: 日次（`StartInterval 86400`）で十分か（週次でも可）。→ 実装時に既定=日次で提案したが、実装結果は平日週3回で確定済み（下記「実装結果」参照）。
- （保持日数＝30日・方式＝Trash移動 は 2026-07-08 裁定済み）

## 関連

- 引き金: W4評価の指摘②（外付けSSD退避リスク）／`plans/active/2026-07-08-計画実行フロー統一/plans/05-…`
- 雛形: `loops-registry/loops/board-reconcile/`（plist・scripts・loop.md の型）
- 卒業先: 成熟したら `loops-registry/plans/loop/` → loop本体（areas/AGENTS.md §5）

## 実装結果

※ 以下は2026-07-09時点で記録済みだった実装状況を、子05のarea標準pilot（新テンプレ移行）で本セクションへ転記したもの。`planctl`による自動追記ではない（本計画はplanctl運用開始前に実装されたため）。

- loop一式を実装済み: `loops-registry/loops/session-record-prune/`（`scripts/prune.py`・`scripts/prune.sh`・
  plist・`loop.md`・`tests/test_prune.py`）。Python テスト **11本緑**（保持境界・.jsonl限定・対象外ディレクトリ
  非接触・Trash移動・同名衝突連番・symlink逃げ非対象 を検証）。実ファイル存在を2026-07-16に再確認済み。
- 実物 **dry-run 実測**: 保持30日超 = **213件 / 1.08GB**（Codex 203 / Claude 10）。dry-run のため実ファイルは不変。
- **未ロード**（launchd 有効化は人間ゲート・未実施）。残: 人間が dry-run ログを確認 → `loop.md` の手順で有効化。
  頻度は **平日 月・水・金 18:00**（`StartCalendarInterval`・約2日おき・2026-07-09 裁定）で実装済み。
  有効化すれば完了条件を全て満たす見込み。

## 終了記録

archive時に必須。実行中は記入しない。
