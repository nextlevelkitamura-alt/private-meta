# hooks-registry — runtime フック本体（機構共有＋runtime受け口の箱）

各 AI ランタイム（Claude Code / Codex 等）の hook script の正本を置く場所。
`loops-registry` / `global-skill-registry` / `repo-registry` と揃えた `-registry` 系。
hook は「イベント直後に軽い決まった処理を挟む」もの（記録・通知など。判断不要・高速・非ブロッキング）。
実行方式の位置づけは `../loops-registry/references/loop-types.md` の ③hook。

## 構造（機構の共有 × runtime受け口〔イベント別〕）

- `hooks/<機構>/` … その機構の **runtime非依存の共有部**（エンジン・共通ロジック・手順md・機構ルール）。
- `claude/<イベント>/` … **Claude 受け口**（イベント別folder＋機構ファイル `<機構>-<イベント>.py`／prompt型 md）。
- `codex/<イベント>/` … **Codex 受け口**（イベント別folder＋`<機構>-<イベント>.py`／登録 `hooks.json` は箱直下）。
- `references/` … hook の恒久リファレンス（runtime別詳細＋比較・md・更新して使う）。
- `research/YYYY-MM-DD/` … 調査メモ（正本ではない）。

受け口（`claude/…`・`codex/…`）は薄いシムに徹し、`realpath` で自分の実体を解決して
共有本体 `hooks/<機構>/`（`board.py`・`common.py`・手順md）を相対 import／参照する。
将来フックが増えたら `hooks/<新機構>/` に共有を、各 runtime の該当イベントfolderに `<新機構>-<イベント>` を足す。

## runtime への露出（symlink 窓）

正本は repo、runtime 側には窓（symlink）と適用済み設定だけを置く（`GLOBAL_AGENTS.md` と同型）。

- `~/.claude/agent-hooks` → `hooks-registry/claude/`（ディレクトリ窓）。`~/.claude/settings.json` は
  `~/.claude/agent-hooks/<機構>/…` の安定パスを指す（保存で自動反映・trust不要）。
- `~/.codex/agent-hooks` → `hooks-registry/codex/`（ディレクトリ窓）。
- `~/.codex/hooks.json` → `hooks-registry/codex/hooks.json`（repo正本への file symlink・session-board が唯一の Codex フックである前提。増えたら merge 方式へ）。
  hook を変えたら Codex で `/hooks` 再 trust（trust は hash/パスに紐づく）。

機構が増えても settings 側のパスは変わらない（窓は箱1本）。手動確認は `ls -la`（矢印 `->`＋先頭 `l`）／`readlink -f`（最終実体）。

## 現在の機構

- `session-board/` … セッション宣言型ボード（唯一の稼働フック・2026-07-05再構築・skill廃止・2026-07-06 registry再編）。
  - 共有＝`hooks/session-board/`（`board.py` エンジン＋`common.py` 受け口共通＋`session-start.md`/`session-end.md` 手順＋`daily-template.md`＋`README.md`＋`registered.sh`）。
  - 受け口＝`claude/<イベント>/`・`codex/<イベント>/` にイベント別（session-start／prompt-register／session-end／subagent＝両runtime＋claude:milestone）。ファイル名 `session-board-<イベント>`。codex は `hooks.json` を箱直下に。
  - 状態は🟢動作中/⏸停止・確認待ち/🔵サブ稼働中の3値。詳細は各 `session-board/AGENTS.md`、現況は `hooks/session-board/registered.sh`。
- `session-daily-log/` … **廃止・削除済み（2026-07-06）**。旧 Stop hook（当日デイリー自動ログ）。session-board へ統一。経緯は `../loops-registry/実行一覧/personal-os.md`。

## 規律

- 本文はここが正本。runtime登録（settings.json/hooks.json/trust）は露出＝人間ゲート。**例外**: session-board の hook 登録・更新・**symlink 露出**は包括承認済み（2026-07-05・承認ルールB）。他フックの追加・削除は人間ゲート。
- hook は**非ブロッキング**（内部失敗でも本体セッションを止めない）。secret/token/値を書かない（ポインタのみ）。
- **フックの実装言語＝既定 Python。** hook本体は stdin の JSON を読み・状態を構造化編集し（flock/原子的書き込み）・単体テストで守るため、ロジックを持つものは Python（`board.py`・`common.py`・受け口 `.py`）。shell を使ってよいのは launchd/cron の入口（`cd` して `.py` を呼ぶ薄い起動役）／繋ぐだけのグルー／ワンショット診断（`registered.sh`）／パイプ集計 のみ。**迷ったら Python。** テストも原則 Python（`board.py` を import して関数を直接検証／通しの E2E だけ `tests/*.sh`）。パースやロジックが要る所は loop でも `.py`（例: `notion_helper.py`）。
- 記録の住み分け: dispatch されたジョブ（`AIJOBS_RUN=1`）・subagent（`agent-*`／`*/subagents/*`）は記録しない。ad-hoc な対話だけ拾う。
- global 運用ルール（Claude/Codex 共通の動き方）は `GLOBAL_AGENTS.md` が正本・各 runtime へ symlink 済み。**hook 側にコピーしない**（二重管理禁止）。
- `CLAUDE.md` は `AGENTS.md` への相対symlink。
