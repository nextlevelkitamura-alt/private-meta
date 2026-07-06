# session-board — セッション宣言型ボードの機構

当日デイリー2節ボード（`## 動いているエージェント` / `## 終わったこと`）を駆動する一式。
**skillは廃止**（2026-07-05）。**registry再編済み**（2026-07-06）＝共有本体はここ、受け口は sibling の箱。
手順md・エンジン・受け口すべて正本はこの repo（runtime へは symlink 窓で露出）。

## 構成（共有本体＝このフォルダ）

- `board.py` … 編集エンジン（key で行操作・flock・冪等）
- `common.py` … 受け口の共通ロジック（両 runtime の薄いシムが `realpath` で解決して import）
- `session-start.md` / `session-end.md` … 手順md（runtime中立）
- `daily-template.md` … デイリー雛形
- `registered.sh` … 現況診断（登録・symlink窓の一覧・唯一の `.sh`）
- 構成・共有/分離の正本は `AGENTS.md`（このフォルダ）。ここでは重複させない。

受け口は各 runtime 箱の**イベント別folder**に分離（`../../claude/<イベント>/`・`../../codex/<イベント>/`）。
命名: 受け口は `<機構>-<イベント>`（例 `session-board-session-start.py`・自己記述）。手順md（`session-start.md`等）は共有本体に置きイベント名で対応する。

## 動作モデル（毎ターン確認は廃止・節目だけ確認）

1. **登録**（UserPromptSubmit / `prompt-register.py`）: 最初のプロンプトで「動いているエージェント」へ🟢1行を機械登録。⏸の行は次プロンプトで🟢復帰。
2. **状態flip**（Stop / `session-end.py`）: 応答終了で🟢→⏸へ機械flip。**ブロックしない**（毎ターンの往復ゼロ）。
3. **節目確認**（Stop / prompt型 `../../claude/milestone/session-board-milestone.md`・Claude専用）: 毎回「大目標達成＋満足の気配か」を判定。
   - 未達 → `{"ok":true}`（普通に停止・確認なし）
   - 節目 → `{"ok":false,"reason":"完了報告手順を実行せよ"}` → `session-end.md` の①②③が注入される
4. **入れ子記録**: 節目ごとに `board.py log` で「終わったこと」の `### repo` > `- 親` の下へ `  - HH:MM 子` を積む。完了で `finish`（自行削除＋親確定）。

## board.py コマンド

```
board.py add    --key K --repo R --type T --summary S [--time HH:MM]
board.py update --key K [--repo R] [--type T] [--summary S]
board.py flip   --key K --state run|wait|sub
board.py log    --key K --repo R --parent P --entry E [--entry E ...]
board.py finish --key K --repo R --parent P [--entry E ...]
board.py check  --key K            # missing|run|wait|sub
```

## 状態（3値）

- 🟢 **動作中**（run）… 自分が処理中
- 🔵 **サブ稼働中**（sub）… バックグラウンドのサブエージェント待ち。**Stopで⏸にならず維持**され、
  プロンプト送信でも🟢に戻さない（サブ完了までエージェントが `flip --state run` で戻す・Codex は `subagent.py` が自動）。
- ⏸ **停止・確認待ち**（wait）… 手が空いた。次プロンプトで🟢復帰。

`session-end.py`（Stop）は `run` のときだけ⏸へflip（`sub`/`wait`は触らない）。
`prompt-register.py` は `wait` のときだけ🟢復帰（`sub`は触らない）。よって sub は board.py に追加するだけで既存受け口が自然に維持する（2026-07-05）。

## 登録（窓経由・登録は人間ゲート／session-board は包括承認）

正本は repo、runtime には **symlink 窓**で露出する。

- **Claude** `~/.claude/settings.json`（パスは窓 `~/.claude/agent-hooks/<イベント>/…`・trust不要・保存で自動反映）:

```json
{ "hooks": {
  "SessionStart":     [{ "matcher":"startup|resume|clear|compact",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/session-start/session-board-session-start.py","timeout":10}] }],
  "UserPromptSubmit": [{ "matcher":"",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/prompt-register/session-board-prompt-register.py","timeout":10}] }],
  "Stop": [
    { "matcher":"", "hooks":[{"type":"command","command":"~/.claude/agent-hooks/session-end/session-board-session-end.py","timeout":10}] },
    { "hooks":[{"type":"prompt","prompt":"<claude/milestone/session-board-milestone.md の内容>"}] }
  ]
}}
```
（実ファイルは絶対パス `/Users/…/.claude/agent-hooks/<イベント>/…` で記述）

- **Codex** `~/.codex/hooks.json` → `../../codex/hooks.json` への **symlink**（repo が正本）。
  パスは窓 `~/.codex/agent-hooks/<イベント>/…`。**hook を変えたら `/hooks` 再 trust**（hash/パスに紐づく）。

窓の実体: `~/.claude/agent-hooks → hooks-registry/claude/`、`~/.codex/agent-hooks → hooks-registry/codex/`。現況は `registered.sh`。

## ガード（登録・作用しないもの）

- `AIJOBS_RUN` 非空（headless）／ session id が `agent-*`（subagent）／ transcript が `*/subagents/*`。

## テスト用 env

- `GOAL_BASE`（デイリー基点）／ `SESSION_BOARD_DATE`（YYYY-MM-DD）／ `SESSION_BOARD_TEMPLATE`。
- 受け口は窓越しに叩いて検証できる（例: `echo '{...}' | ~/.claude/agent-hooks/prompt-register/session-board-prompt-register.py`）。`realpath` で共有本体を解決するので窓経由でも `board.py` を正しく指す。

## 既知の制約

- 強制終了（ウィンドウkill）では Stop が走らず🟢が残る → 掃引は朝夜会。
- 日付跨ぎで前日の⏸行が残る → 掃引は朝夜会。
- 節目判定はモデル依存＝確率的。迷ったら素通し設計で「聞かなさすぎ」に倒す。
- Codex接続（`codex/`）は実装・登録・trust 済み（開始🟢/Stop⏸ 実測PASS・サブ🔵自動は未実測）。`board.py`・`common.py`・手順md は runtime非依存で共用。詳細は `../../codex/AGENTS.md`。

計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/`（registry再編は `planning/2026-07-06-hooks-registry再編とsymlink露出/`）。
