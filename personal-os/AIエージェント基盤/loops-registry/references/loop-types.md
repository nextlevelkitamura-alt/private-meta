# ループ実行方式（種類・判断軸・現状）

自動処理は次の**3方式**で回す。**迷ったら①キュー（Orca経由）。安定してから②headless へ卒業させる。**
起動の仕組み（launchd＋dispatcher＋runner）の詳細は `loop-runbook.md`、実行レーンの契約は `../ai-jobs/AGENTS.md`。

## ① キュー実行（ai-jobs）→ Orca 経由　← 基本はこれ

**判断軸（いつ選ぶ）**: 人間の**介入・方向修正が起こりうる**もの。新規性が高い／リスクがある／結果を見て判断したい／新モデルを試す／一度きりで様子見。
**システムが安定するまでは、まずこのキュー（Orca 経由）で実行するのを基本**にする＝見えて・止めて・引き継げるから。

- やり方: `ai-jobs/ready` にカードを置く → 監督（＝チャットの AI）が `orca` CLI で worktree/端末を立て、起動 → 監視 → 介入 → 引き継ぎ → closeout。
- 監視: `orca worktree ps` / `orca terminal read`。watchdog（詰まり検知）: `orca terminal wait` または「新コミット待ち」の background poll。
- 現状: ⑤hook 実装を Orca 経由で実走（枠切れ→別engine引き継ぎ→完走まで実証）。無人の `loops/ai-jobs-dispatcher`（headless dispatcher）も実装済みだが、実走スモーク未了のため**主線はキュー（Orca）**。

## ② headless（定時・無人）

**判断軸（いつ選ぶ）**: 処理が**定型で安定**していて**人間の関与が要らない**もの。定時/間隔で回してよい・低リスク・結果が予測できる。→ **①キューで安定した処理を卒業させる先**。

- やり方: launchd が時間/間隔で自動起動。runner: `ai`（判断要）/ `script`（機械処理）。
- 現状: 稼働中の headless loop は無し。旧例 `loops/daily-digest`（夜loop・`auto:done`/`auto:align` 生成）は 2026-07-06 廃止（session-board へ統一）。

## ③ hook（イベント発火）

**判断軸（いつ選ぶ）**: 何かの**イベント直後に軽い決まった処理**を挟むだけのもの。判断不要・高速・非ブロッキング（記録／通知など）。

- やり方: ランタイムの hook で発火。
- 現状: `hooks-registry/hooks/session-board/`（Claude Code の `SessionStart`/`UserPromptSubmit`/`Stop` → 当日デイリーの「動いているエージェント」節を宣言型で機械管理）。状態: 登録済み（`~/.claude/settings.json`）。旧 `hooks/session-daily-log` は 2026-07-06 削除（session-board へ統一）。

## 選び方（まとめ）

- 介入・方向修正がありうる／新規／様子見 → **① キュー（Orca）**（＝安定するまで既定）
- 定型・安定・無人でよい定時処理 → **② headless**（①から卒業させる）
- イベント直後の軽い記録・通知 → **③ hook**
