# 実行一覧 — personal-os（`com.kitamura.*`）

実測確認: `launchctl list | grep com.kitamura` ／ 最終更新: 2026-07-09（記録削除 loop 1本を draft 追加・未ロード）

## 1行で

**2026-07-04、旧レンダリング系を全停止した。** 人間のデイリーが91%機械生成になり読めなくなったための白紙化。新設計（セッション宣言型 session-board）は稼働中（主経路は hook 駆動・launchd不使用）で、その生存照合の**保険**だけを launchd に1本置いている（下記 board-reconcile）。

## ジョブ（稼働中・2026-07-08〜）

- `board-reconcile`（5分毎 StartInterval） ── session-board の生存照合（🟢/🔵の沈黙→⏸）の保険。通常は Stop/SessionStart 相乗りで照合されるため、**全セッションを閉じて放置した間の古い🟢残留だけ**を埋める。実体は瞬時・非LLM・API呼び出しなし。plist 正本・停止手順は `../loops/board-reconcile/loop.md`（symlink＋bootstrap・daily-notion-sync と同型）。2026-07-08 kickstart 実測 exit0。

## draft（未ロード・有効化は人間ゲート）

- `session-record-prune`（平日 月水金 18:00・StartCalendarInterval・**未ロード**） ── 古いセッション記録（`.jsonl`）を保持30日超で `~/.Trash` へ移す（削除でなく移動＝復旧余地）。内蔵ディスク逼迫（95%）の抑制。2026-07-09 新設・Python テスト11本緑・実物 dry-run 実測 **213件/1.08GB** が対象。**初回 dry-run を人間が確認してから有効化**（board の生存判定は直近30分しか見ないため古い除去は無害）。plist 正本・手順は `../loops/session-record-prune/loop.md`。

## 停止したもの（2026-07-04・全て bootout 済み）

- `lanes-sync`（renderer・毎分） ── デイリー盤面と Notion レーン実況の同期。
- `watch-keeper`（5分毎） ── 見張り番の検知通知。cockpitフック撤去（同日）により検知対象も消滅。
- `inbox-patrol`（30分毎） ── 依頼インボックス未処理行の自動起案。
- `daily-digest`（12:30/18:30/23:30） ── デイリー集計とダイジェスト（`claude -p` でLLM要約＝トークン消費あり）。
- `exec-audit`（月・木 10:00） ── launchd ドリフト検出。
- `ai-jobs-dispatcher` ── 元から休眠（モードB裁定）。変更なし。

hook 側も同日撤去済み: Claude Code Stop hook（`hooks/session-daily-log/`）を `~/.claude/settings.json` から除去（hooks は空）。スクリプト本文は当初 repo に残置したが、2026-07-06 に削除（renderer/daily-digest も廃止し session-board へ統一）。詳細は `../../hooks/AGENTS.md`。

## 実機の状態

- `launchctl list | grep com.kitamura` → 0件。
- `~/Library/LaunchAgents/` の symlink 5本は `_retired-20260704/` へ退避（ログイン時の再ロード防止・plist 正本は各 `loops/<loop>/` に残置）。

## 再開する場合（人間ゲート）

1. `~/Library/LaunchAgents/_retired-20260704/` から対象 symlink を戻す。
2. `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.<loop>.plist`
3. この一覧を稼働状態に更新する。

## 停止理由の記録（2026-07-04）

- デイリー（2026-07-03）が 674行/141KB・auto区画91%・auto:log 101行（subagent 37／commit無し 78／loop自己記録 21）に肥大し、人間の記入が埋もれた。
- 記録内容は git log と transcript に既存＝二重管理。hook は renderer の backfill と重複。
- 方針: 「全部を生記録して後から機械がまとめる」設計をやめ、「各セッションが開始時に意図を宣言し、終了時に完了チェックとプロジェクト別の成果箇条書きを自分で書く」設計へ作り直す（計画は `my-brain/areas/ai運用/plans/` に起こす予定）。

## 実行メニュー（手動オンデマンド・スクリプト自体は健在）

- デイリー集計: `loops/daily-digest/scripts/run.sh [YYYY-MM-DD] [--snapshot]`
- 実行監査: `loops/exec-audit/scripts/audit.sh`（読み取りのみ）
- 依頼インボックス巡回: `loops/inbox-patrol/scripts/patrol.sh [YYYY-MM-DD] [--dry-run]`
- 見張り番キーパー: `loops/watch-keeper/scripts/keeper.sh`（読み取りのみ）
- 詳細は各 `loop.md` と `loops-registry/ai-jobs/AGENTS.md`。
