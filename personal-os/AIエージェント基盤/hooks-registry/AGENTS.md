# hooks-registry — グローバル hook の唯一の正本

Claude Code と Codex がグローバルに実行する hook を、ここで一元管理する。実行本体は runtime ごとに複製せず、`events/` に1組だけ置く。現在稼働する機構は session-board だけである。

## まず見る場所

```text
hooks-registry/
├── events/                         # runtimeが実行する共通Python本体
│   ├── session-start/               # reconcile-and-notify.py + 同名.md
│   ├── prompt-register/             # register-and-guide.py + 同名.md
│   ├── session-end/                 # mark-wait.py + 同名.md
│   └── subagent/                    # sync-subagent-status.py + 同名.md
├── shared/session-board/            # 状態・永続化・CLIの共通エンジン
├── claude/                          # Claudeの登録先と更新規則の説明
├── codex/hooks.json                 # Codex登録のrepo正本
└── references/                      # runtime仕様の恒久リファレンス
```

各 `events/<イベント>/` では、`機能名.py` と同名の `機能名.md` が必ず対になる。runtime が実行するのは `.py` だけ。`.md` と `AGENTS.md` は、人間とAIが変更前に読む説明書であり、実行しない。

## 実行の流れ

| runtimeイベント | 実行本体 | すること |
| --- | --- | --- |
| `SessionStart` | `events/session-start/reconcile-and-notify.py` | 生存照合とキー通知 |
| `UserPromptSubmit` | `events/prompt-register/register-and-guide.py` | ボード登録と開始ガイド |
| `Stop` | `events/session-end/mark-wait.py` | 🟢を⏸へ更新 |
| `SubagentStart/Stop` | `events/subagent/sync-subagent-status.py` | 🔵と体数を同期 |

状態の正本は `shared/session-board/`。🟢動作中 / ⏸停止・確認待ち / 🔵サブ稼働中の3値だけを使う。

## runtime への露出と登録表

- `~/.claude/agent-hooks` と `~/.codex/agent-hooks` は、この `hooks-registry/` 全体への symlink。両runtimeは同じ `events/` のPythonを呼ぶ。
- Claudeの登録表は `~/.claude/settings.json` の `hooks` 項目。ここにはhooks以外の設定も同居するため、repoへコピーせず、settings全体もsymlinkにしない。保存すると反映され、trustは不要。
- Codexの登録正本は `codex/hooks.json`。`~/.codex/hooks.json` はそのsymlinkで、変更後は人間が `/hooks` で再trustする。

Claudeの登録を変える時は、`~/.claude/settings.json` の `hooks` 項目だけを直接更新する。repo内にClaude専用の `hooks.json` や同期スクリプトは置かない。

## 規律

- hook は非ブロッキング。内部失敗・対象外入力で本体セッションを止めない。
- ロジックはPython。shellは現況診断 `shared/session-board/registered.sh` のような薄い補助だけ。
- runtime固有の差は、登録表とstdout形式だけに閉じる。状態ロジックは `shared/session-board/common.py` に集約する。
- 設定・登録を変えた後は `shared/session-board/registered.sh` で窓を読み取り確認し、Codexだけは `/hooks` の人間操作で再trustする。secretや設定値をrepo・説明書へ書かない。
- `CLAUDE.md` は必ずこの `AGENTS.md` への相対symlink。READMEは置かない。
