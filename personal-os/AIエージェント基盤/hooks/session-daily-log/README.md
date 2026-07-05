# session-daily-log

Claude Code の `Stop` hook で、当日のデイリー `## ログ(自動)` の `auto:log` マーカー内にセッションポインタを1行 upsert する。

書き込む形式は次の1行（cwd が git 配下でなければ repo/branch/dirty/commits は省く＝後方互換）。

```text
YYYY-MM-DD HH:MM JST | cwd=<path> | repo=<名> | branch=<名> | dirty=<数> | commits=<short-sha,...> | session=<id> | transcript=<path>
```

載せるのは**ポインタ／メタのみ**。`commits` はセッション中に cwd の repo で積まれた **short-sha（＝git へのポインタ）**で、コミット本文・差分・token・secret・環境変数値は書かない。件名などの本文は renderer（`../../loops-registry/loops/renderer/`）が git から解決して `auto:done` に出す。同一 `session=<id>` の既存行は差し替え、無ければ追記する。

## 動作

- stdin の Stop hook JSON から `session_id` / `cwd` / `transcript_path` / `hook_event_name` を読む。
- `cwd` が git 配下なら `repo`（toplevel の basename）/ `branch` / `dirty`（未コミット数）を足し、transcript 先頭 timestamp をセッション開始として `git log --since` でその後の commit short-sha を `commits` に入れる。git 呼び出しはすべて失敗を握りつぶす（値が取れないフィールドは省く＝non-blocking）。
- `loops-registry/loops/daily-digest/scripts/_paths.sh` の `daily_file_for` で当日デイリーを決める。
- `get-marker-block.sh` で `auto:log` 内側だけを読み、同一 session 行を upsert する。
- `set-marker-block.sh` で `auto:log` 内側だけを書き戻す。
- `AIJOBS_RUN` が非空なら何も書かない（renderer起動も含め全処理を抑止・維持）。
- 当日デイリーが無い、`auto:log` マーカーが無い、JSON が不足している場合は安全に no-op する
  （当日デイリーが無い場合は upsert をスキップするが、後述の renderer 起動は行う）。
- **末尾で renderer（`../../loops-registry/loops/renderer/scripts/render-debounced.sh`）を非同期
  debounce起動する。** 呼び出し元（Stop本体）を絶対にブロックしない（バックグラウンド起動＋`disown`
  してすぐ `exit 0` する）。当日デイリーが無い場合も、upsert をスキップした上でこの起動だけは行う
  （デイリー自体は renderer が生成し、upsert の取りこぼしは renderer の Claude backfill が拾う）。
  renderer スクリプトが無い・実行不可の場合は何もせず握りつぶす（このhookは renderer に依存しない）。

テスト時だけ次の env を使える。

- `GOAL_BASE`: daily-digest の `_paths.sh` が読むデイリー基点。
- `SESSION_DAILY_LOG_DATE`: `YYYY-MM-DD`。当日判定を固定する。
- `AI_AGENT_FOUNDATION_ROOT`: この repo の root を明示する。
- renderer 側の env（`DAILY_TEMPLATE` / `CLAUDE_PROJECTS_BASE` / `CODEX_INDEX` /
  `CODEX_SESSIONS_BASE` / `RENDERER_STATE_DIR` / `RENDERER_DEBOUNCE_SECONDS` 等）は
  `../../loops-registry/loops/renderer/loop.md` 参照。

## Claude Code 登録スニペット

`~/.claude/settings.json` の既存 `hooks.Stop` に追記する。本体は全セッションへ効くため、この repo 側では設定ファイルを直接編集しない。

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/hooks/session-daily-log/session-daily-log.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

既に `Stop` hook がある場合は配列全体を置き換えず、上の hook handler だけを追加する。

> 補足: この repo 直下の `hooks/` は新しいトップレベルフォルダなので、統合時に基盤 `AGENTS.md` のフォルダ地図へ1行追加する（このワーカーは地図を改変しない方針のため未反映）。

## 抑止方式（AIJOBS_RUN・実測）

Claude Code **2.1.197** で実測（`~/.claude` は触らず `--settings` にインライン JSON で一時 Stop hook を仕込む方式）。

- 親プロセスに `AIJOBS_RUN=1` を立てて `claude -p` を起動 → Stop hook 側で `AIJOBS_RUN=[1]` を観測（**継承する**）。
- 立てずに起動 → hook 側は `AIJOBS_RUN=[<unset>]`（通常セッションは抑止されない）。
- 本 hook 実体を使った end-to-end でも、`AIJOBS_RUN=1` の実 claude セッションは `auto:log` に1行も書かず、非設定の実セッションは実 `session_id`/`cwd`/`transcript_path` を1行 upsert することを確認。

したがって cwd 判定 fallback は不要。env 継承で抑止できる。

**要・基盤側変更**: dispatcher / runner（headless レーン）が Claude worker の `claude` プロセスを spawn する時、`env` に `AIJOBS_RUN=1` を1行足す必要がある（dispatched セッションはカードが記録し、この hook では二重記録しないため）。この1行が無いと、dispatch 起動の worker セッションも `auto:log` に書き込まれる。

## 既知の制約

- 同一分内に複数セッションがほぼ同時に `Stop` した場合、read→modify→write が競合して片方の行を取りこぼす可能性がある（`set-marker-block.sh` は `mktemp`＋`mv` の原子置換なのでファイル破損はしない）。個人 OS 規模では許容し、取りこぼしは夜loop(⑥)の再生成で吸収する。

## Codex 側メモ（要否調査）

**要否の結論: 今回は不要。** この deliverable は Claude Code の `~/.claude` Stop hook で、Codex には登録しない。Codex は Claude と別の hook 系統なので、この Claude 設定は Codex 対話セッションには一切効かない。

Codex 対話セッションも同じ `auto:log` に集めたくなった場合に初めて、Codex 側で別途 hook 登録が必要になる（別作業）。その際の前提:

- **未実測の項目（実装前に Codex 公式ドキュメントで実測すること）**: Codex の lifecycle hook の有無、セッション終了 event 名、stdin で渡る入力フィールド名（`session_id` / `transcript_path` / `cwd` 相当があるか）、登録場所（`~/.codex/` 配下 or `config.toml` 等）、command hook の trust 手順。このワーカーは Codex hook を実測していないため、フィールド名や登録パスを確定情報として書かない。
- 本 `session-daily-log.sh` は Claude の Stop JSON（`session_id`/`cwd`/`transcript_path`）前提。Codex の入力 JSON が同じキー名なら流用余地はあるが、キー名が違えば読み替えが要る。実機の Codex 入力 JSON を1回ダンプして確認してから判断する。
- 記録の住み分け（出所 plan「記録の住み分け」）は Codex でも同じ: dispatch 経由はカードが記録するので、Codex の headless dispatch レーンでも `AIJOBS_RUN=1` 相当の抑止が要る。拾うのは ad-hoc な Codex 対話だけ。
