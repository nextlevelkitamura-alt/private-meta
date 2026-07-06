# Codex / Claude hooks・agents 現状調査

日付: 2026-07-04
対象: Codex / Claude の hook・agent・Skill露出

## 結論

- Global 指示は共通。`~/.codex/AGENTS.md` と `~/.claude/CLAUDE.md` は、どちらも `personal-os/AIエージェント基盤/GLOBAL_AGENTS.md` への symlink。
- hooks は別物。Claude は `~/.claude/settings.json` に global hook が登録されている。Codex は global hook というより、repo-local の `.codex/hooks.json` が中心。
- agents も別概念。Claude の agent は `~/.claude/agents/*.md`。Codex 側は主に Skill の `agents/openai.yaml` で、表示名・説明・起動プロンプトを持つメタデータ。

## Claude 側

### Global 指示

- `~/.claude/CLAUDE.md -> ../Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md`

### hooks

登録場所: `~/.claude/settings.json`

登録されている主なイベント:

- `Notification`
- `Stop`
- `SessionStart`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `StopFailure`
- `PostToolUseFailure`
- `PermissionRequest`

主な処理:

- LINE通知: `~/.claude/line-notify.sh`
- macOS通知: `osascript display notification`
- cockpit 状態更新: `AGI_COCKPIT_STATUS_FILE` への `running` / `waiting_confirmation` 書き込み
- Orca hook: `~/.orca/agent-hooks/claude-hook.sh`
- session daily log: `personal-os/AIエージェント基盤/hooks/session-daily-log/session-daily-log.sh`

AIエージェント基盤で正本管理されている hook は `session-daily-log/`。これは Claude Code の `Stop` イベントで当日デイリー `auto:log` にセッションポインタを書き、renderer を非同期起動する。

### agents

登録済み Claude agent:

- `~/.claude/agents/fixer.md`
  - name: `fixer`
  - 用途: エラー修正特化
  - 説明: `/tdd` から自動委任される
  - tools: `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`

## Codex 側

### Global 指示

- `~/.codex/AGENTS.md -> ../Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md`

### hooks

`~/.codex/config.toml` に `[hooks.state]` はあるが、現状の中身は旧 focusmap パスへの trust 状態:

- `/Users/kitamuranaohiro/Private/P dev/focusmap/.codex/hooks.json:pre_tool_use:0:0`
- `/Users/kitamuranaohiro/Private/focusmap/.codex/hooks.json:pre_tool_use:0:0`

上記2つの `.codex/hooks.json` は現時点で存在しなかった。片方は `enabled = false`。

実体が存在する repo-local Codex hooks:

- `projects/active/focusmap/.codex/hooks.json`
- `projects/active/focusmap-worktrees/*/.codex/hooks.json`
- `projects/active/仕事/.codex/hooks.json`

focusmap 系の主な内容:

- `Stop`: `.codex/hooks/auto-commit.sh` を非同期実行
- `PreToolUse` / `Bash`: `git push.*main` をブロック

仕事 repo の主な内容:

- `PostToolUse` / `TodoWrite`: AI todo sync
- `PostToolUse` / `Bash`: profile URL 抽出
- `PostToolUse` / `mcp__line-reader__*`: LINE送信後・候補者追加後・会話取得後の処理
- `Stop`: deferred削除、cleanup、自動コミット

注意: `focusmap` と `仕事` の Stop hook には `git add -A` が含まれる。Private / AIエージェント基盤の現在ルールでは `git add -A` を避ける方針なので、ユーザー未コミット変更を巻き込むリスクがある。

### agents / Skill metadata

Codex 側に `~/.codex/agents` は見当たらなかった。

代わりに、複数の Skill が `agents/openai.yaml` を持つ。これは Claude の subagent ではなく、Codex向けの表示・起動メタデータ。

確認できた主な `agents/openai.yaml`:

- `.system/imagegen`
- `.system/openai-docs`
- `.system/plugin-creator`
- `.system/skill-creator`
- `.system/skill-installer`
- `handoff-plan-supervisor`
- `imagegen-mockup`
- `macro-code-planning`
- `micro-code-planning`
- `naiyou-suriawase`
- `nextlevel-app-calendar-links`
- `notion-spec-to-implementation`
- `playwright`
- `repo-create`
- `screenshot`
- `settings-ui-architect`
- `skill-creator-codex`
- `skill-visualizer`
- `sora`
- `trading-edge-research`

## Skill露出の違い

共通 symlink 露出されている主な Global Skill:

- `cockpit-supervisor`
- `coding-task-orchestrator`
- `grill-me`
- `html`
- `naiyou-suriawase`
- `orca-cockpit`
- `plan-ops`
- `plan-triage`
- `project-slide-workflow`
- `repo-create`
- `repo-relocation`
- `skill-creator-codex`
- `skill-creator-custom`
- `skill-delete`
- `skill-visualizer`
- `task-router`
- `video-transcription`

Codex側に寄っているもの:

- `.system`
- `handoff-plan-supervisor`
- `imagegen-mockup`
- `macro-code-planning`
- `micro-code-planning`
- `nextlevel-app-calendar-links`
- `notion-spec-to-implementation`
- `playwright`
- `screenshot`
- `settings-ui-architect`
- `sora`
- `ui-ux-pro-max`

Claude側に寄っているもの:

- `images-generate`
- `images-generate-workspace`
- `kimi-webbridge`
- `mcp`
- `playwright-scout`
- `sleep`
- `slide`
- `sns-post`

## outputs 配置ミスの原因

今回、最初に `personal-os/AIエージェント基盤/outputs/reports/2026-07/` へHTMLを置いた判断は誤り。

原因は次の4つ。

1. `~/Private/AGENTS.md` の「Skillやツールが生成する成果物は、所属repoの `outputs/<用途>/YYYY-MM/` に置く」という規約を機械的に適用した。
2. `html` Skill の「回答・調査まとめをHTML Artifactにする」という指示を受け、Codex環境では Artifact ではなくローカルHTMLファイルとして保存する判断をした。
3. 「所属repo」を、調査対象である `AIエージェント基盤` repo 全体と解釈し、用途を `reports`、期間を `2026-07` にした。
4. しかし今回の内容は「hook / runtime登録の調査」であり、`AIエージェント基盤` 直下の汎用 `outputs` ではなく、対象領域である `hooks/` 配下の `research/YYYY-MM-DD/` に置くべきだった。

追加で悪かった点:

- `outputs/` はこのrepoの `.gitignore` で無視されており、最終成果物を追跡する規約とも噛み合っていなかった。
- `AIエージェント基盤` のようなメタ領域で、置き場所の意味を説明せずに新しい汎用フォルダを作った。
- 「表示用HTML」と「継続参照する調査メモ」を分けなかった。今回の正しい成果物は、HTMLよりもこのMarkdown調査メモ。

## 今後の判断

hook / runtime hook / agent登録まわりの調査は、まず次に置く。

```text
personal-os/AIエージェント基盤/hooks/research/YYYY-MM-DD/
```

汎用の `outputs/` は、対象領域の中に置くべき調査・判断・正本候補には使わない。

HTML化が必要な場合でも、正本・調査メモは Markdown として残し、HTMLは表示用の派生成果物として扱う。

## 参照した主なファイル

- `personal-os/AIエージェント基盤/AGENTS.md`
- `personal-os/AIエージェント基盤/hooks/AGENTS.md`
- `personal-os/AIエージェント基盤/hooks/session-daily-log/README.md`
- `personal-os/AIエージェント基盤/hooks/session-daily-log/session-daily-log.sh`
- `~/.claude/settings.json`
- `~/.claude/agents/fixer.md`
- `~/.codex/config.toml`
- `projects/active/focusmap/.codex/hooks.json`
- `projects/active/focusmap-worktrees/*/.codex/hooks.json`
- `projects/active/仕事/.codex/hooks.json`
