分類: loop ／ 種別: 新規作成 ／ 優先: ○ ／ 規模: フル
次: focusmap側Turso接続情報・実スキーマの確認（`projects/active/focusmap/scripts/focusmap-agent/`・`@libsql/client`利用箇所を調査）。

# デイリー状態のTurso表反映（session-board源・2層送信）

## 目的

当日デイリーの「動いているエージェント」「終わったこと」を、focusmapが既に持つTurso(libSQL・「高頻度Codex進捗用」)へ送り、focusmap既存UI（`/dashboard/ai-todos`・`/dashboard/workspace/agents`）で「今日の目標」と「AIの実際の動き」を1画面で俯瞰できるようにする。正本は常にローカルMD（デイリー）。Turso/focusmapは表示専用のミラー。2026-07-08のHTML設計書（AI運用2軸統合設計）の軸2に対応する実装計画。設計書: https://claude.ai/code/artifact/ce9fa3fc-eb6e-4650-baf8-c0a14a7eb8fb

## 現状

- デイリーは session-board（`hooks/session-board/board.py`）がイベント駆動・flock排他で2節を書く（`## 動いているエージェント`／`## 終わったこと`）。同じ源データから Notion 連携（`../2026-07-06-デイリーNotion表反映/plan.md`・実装未着手）が並行進行中。両計画は送信先が別（Notion API／Turso+LLM要約）なので独立に進める。
- 2026-07-08、ユーザー調査依頼を受け4方向調査を実施（本セッション）。「Taso」＝focusmapが採用済みの **Turso（`@libsql/client`・高頻度Codex進捗用）** と判明。Supabase側 `ai_todo_progress` テーブルには `source='schedule_md'` の受け皿が設計時から用意されている（未配線）。`ai_runners`／`api/agents/heartbeat` も稼働中でエージェント状態表示に転用できる。
- focusmap側の実際のTursoスキーマ・接続情報・認証方式は未調査（次の一手）。

## 方針

1. **2層送信アーキテクチャ**（ユーザー裁定・2026-07-08）:
   - **機械送信（同期）**: セッションスタート情報（目標・種別・repo・model等の構造化フィールド）は `board.py` の `add`/`update` 実行時に送る。ただし **MD書き込み・flock解放が完了した後**に短タイムアウトでTursoへ書き込み、**失敗しても `board.py` 呼び出し自体は成功扱い**にする（MDが正本、Tursoはベストエフォート。flock保持時間を伸ばして他セッションを待たせない）。
   - **要約送信（非同期）**: 「終わったこと」の新規logエントリは、`daily-notion-sync` と同型の新設loop（30秒diff検知）が拾い、**LLM API経由で人間向けに変換してからTursoへ送信**する。粒度（logエントリ単体の言い換えか、セッション全体の集約か）は未確定（下記）。
2. **送信先の役割分担**: focusmapの既存DB分担（README「高頻度Codex進捗用はTurso、UI表示・集約はSupabase」）にそのまま乗る。今日の目標一覧・俯瞰は Supabase `ai_todo_progress`（`source='schedule_md'`）、高頻度な動きの生ログはTursoへ。
3. **focusmap側UIは転用のみ**: 新規ページは作らない。`/dashboard/ai-todos` を「今日の目標＋やること」ビューに、`/dashboard/workspace/agents` の heartbeat 表示を稼働状態確認に転用する。
4. **Notion連携とは独立**: `board.py`→MD一本化は変えない。Notion・Turso はどちらもMDからの下流ミラーとして並列に生やす（互いに依存しない）。

## 未確定 / 運用で決める

- focusmap側Turso接続情報・実スキーマ（要調査。認証情報の管理方法＝keychain保管方針もここで決める）。
- 要約送信の粒度（logエントリ単体の言い換え／セッション全体の集約／両方）。
- 要約に使うLLM API・モデル（コスト・呼び出し頻度の管理方針）。
- 機械送信が失敗した場合のリトライ方式（次回呼び出し時に差分送信か、別途reconcile的な仕組みで埋めるか）。
- Supabase `ai_todo_progress` への書き込み経路（Turso経由で中継するか、personal-os側から直接Supabaseにも書くか）。

## 完了条件（レビュー項目）

- [ ] focusmap側のTurso接続情報とスキーマが確認され、personal-os側から書き込み可能な認証経路（keychain等）が用意されている。
- [ ] `board.py` の `add`/`update` 実行時、flock解放後にTursoへ機械送信される（Turso障害時も `board.py` 呼び出し自体は成功する＝実機で意図的に接続を切って確認）。
- [ ] 新設loopが「終わったこと」の新規logエントリを検出し、LLM API経由で要約したうえでTursoへ送信する（30秒diff検知・再実行で重複送信ゼロ）。
- [ ] focusmapの `/dashboard/ai-todos` または `/dashboard/workspace/agents` で、personal-os発のデータが表示される（実機スモーク）。
- [ ] token・認証値がrepo・ログ・デイリーのどこにも出ない（`grep` 確認）。
- [ ] Turso/LLM API障害時にローカルMD運用が一切影響を受けない（失敗は警告のみ・正本はMD）。
