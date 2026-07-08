分類: loop ／ 種別: 新規作成

# セッション記録の定期削除loop

## 目的

Claude / Codex のセッション記録（`.jsonl`）の肥大を、一定期間より古いものを定期削除して抑える。
内蔵ディスク逼迫（95%使用・残11GB）と、それに伴う「外付けSSDへ退避したい」誘惑（＝W4評価の
指摘②が現実化する経路）を根から断つ。

## 現状（2026-07-08 実測）

- `~/.codex/sessions` 4.0G・うち **30日超＝188ファイル**。`~/.claude/projects` 317M・30日超＝10ファイル。
- 直近7日の Codex 記録は 80ファイル（これは残す範囲）。
- session-board の生存判定は**直近30分の mtime しか見ない** → 古い記録は判定に不要（消しても board は無傷）。
- 定期削除の仕組みは無い。手動放置で膨張し続ける。

## 方針（未確定・種まき）

1. **新loop**（`board-reconcile` を雛形に）: `loops-registry/loops/session-record-prune/` を新設。
   launchd 日次（`StartInterval 86400`・`board-reconcile` の plist を踏襲＝zsh入口→scripts）。
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

- **頻度**: 日次（`StartInterval 86400`）で十分か（週次でも可）。→ 実装時に既定=日次で提案。
- （保持日数＝30日・方式＝Trash移動 は 2026-07-08 裁定済み）

## 関連

- 引き金: W4評価の指摘②（外付けSSD退避リスク）／`plans/active/2026-07-08-計画実行フロー統一/plans/05-…`
- 雛形: `loops-registry/loops/board-reconcile/`（plist・scripts・loop.md の型）
- 卒業先: 成熟したら `loops-registry/plans/loop/` → loop本体（areas/AGENTS.md §5）
