# hooks-registry — グローバル hook の唯一の正本

Claude Code と Codex がグローバルに実行する hook を、ここで一元管理する。実行本体は runtime ごとに複製せず、`events/` に1組だけ置く。現在は session-board と、`PLAN_RUN_MANIFEST`がある実行だけを検査するplan-closeout guardが稼働する。

## まず見る場所

```text
hooks-registry/
├── events/                         # runtimeが実行する共通Python本体
│   ├── pre-tool-use/                # 計画guard2つ: バケット生移動deny(bucket-move) + 立案警告のみ(gate・Claude登録済/Codex未登録)
│   ├── session-start/               # reconcile-and-notify.py + 同名.md
│   ├── prompt-register/             # register-and-guide.py + 同名.md + runtime-read分類policy
│   ├── session-end/                 # mark-wait.py + 同名.md
│   └── subagent/                    # sync-subagent-status.py + 同名.md
├── shared/session-board/            # 状態・永続化・CLIの共通エンジン
├── shared/plan-closeout/            # manifestを読む計画closeout guard（状態を書かない）
├── claude/                          # Claudeの登録先と更新規則の説明
├── codex/hooks.json                 # Codex登録のrepo正本
└── references/                      # runtime仕様の恒久リファレンス
```

各 `events/<イベント>/` では、`機能名.py` と同名の `機能名.md` が必ず対になる。runtime が実行するのは `.py` だけ。例外として`prompt-register/session-classification-policy.md`はPythonがplain textで読む短いruntime policyであり、Pythonとして実行しない。その他の`.md`と`AGENTS.md`は人間とAIが変更前に読む説明書で、runtime注入しない。

## 実行の流れ

| runtimeイベント | 実行本体 | すること |
| --- | --- | --- |
| `SessionStart` | `events/session-start/reconcile-and-notify.py` | repo Context、生存照合、キー通知、固定分類policy |
| `UserPromptSubmit` | `events/prompt-register/register-and-guide.py` | ボード登録、turn pending、Theme/Plan候補の短いContext |
| `Stop` | `events/session-end/mark-wait.py` + `guard-plan-closeout.py` | 🟢を⏸へ更新 + `evaluated`未同期の一回だけ継続要求 |
| `SubagentStart/Stop` | `events/subagent/sync-subagent-status.py` + `verify-plan-worker.py` | 🔵と体数を同期 + manifest割当・result/evaluationを検査 |

状態の正本は `shared/session-board/`。🟢動作中 / ⏸停止・確認待ち / 🔵サブ稼働中の3値だけを使う。

## runtime への露出と登録表

- `~/.claude/agent-hooks` と `~/.codex/agent-hooks` は、この `hooks-registry/` 全体への symlink。両runtimeは同じ `events/` のPythonを呼ぶ。
- Claudeの登録表は `~/.claude/settings.json` の `hooks` 項目。ここにはhooks以外の設定も同居するため、repoへコピーせず、settings全体もsymlinkにしない。保存すると反映され、trustは不要。
- Codexの登録正本は `codex/hooks.json`。`~/.codex/hooks.json` はそのsymlinkで、変更後は `codex/trust-current.py` がCodex app-serverの `hooks/list` で現在hashを取得し、公式config APIで再trustする。

Claudeの登録を変える時は、`~/.claude/settings.json` の `hooks` 項目だけを直接更新する。repo内にClaude専用の `hooks.json` や同期スクリプトは置かない。

## 規律

- hook は非ブロッキング。内部失敗・対象外入力で本体セッションを止めない。
- `PLAN_RUN_MANIFEST`が無い通常セッションにはplan-closeoutを作用させない。正常に検証できた未同期または必須成果物欠落だけ、`stop_hook_active`がfalseの時にStop / SubagentStopで一回継続を要求できる。trueなら再blockせず通す。
- plan-closeoutは計画本文・バケット・manifest・result packet・worktreeを変更しない。計画日付は`planctl rename --check`で案内するだけである。
- ロジックはPython。shellは現況診断 `shared/session-board/registered.sh` のような薄い補助だけ。
- runtime固有の差は、登録表とstdout形式だけに閉じる。状態ロジックは `shared/session-board/common.py` に集約する。
- Focusmap分類は既存UserPromptSubmit handlerの内部で直列化し、同じイベントへ第2handlerを増やさない。固定policyは各SessionStartイベント（startup/resume/compact等）で再注入し、毎Promptは今日＋対象repoの短い動的packetだけ、明示再分類は`skills/session-routing`と分ける。
- 設定・登録を変えた後は `shared/session-board/registered.sh` で窓を読み取り確認し、Codexは `codex/trust-current.py` を実行してtrust状態をreadbackする。secretや設定値をrepo・説明書へ書かない。
- `CLAUDE.md` は必ずこの `AGENTS.md` への相対symlink。READMEは置かない。
