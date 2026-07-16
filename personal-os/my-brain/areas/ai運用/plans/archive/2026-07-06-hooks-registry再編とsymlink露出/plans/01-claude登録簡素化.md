親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
並列: 可 ／ レビュー: 都度

# Claude登録を直接設定へ戻す

## 目的

Claudeのhooks登録を公式の `~/.claude/settings.json` に直接集約し、repo内の独自同期器をなくす。

## 現状

`claude/hooks.json` と `apply-hooks.py` がsettings.jsonの `hooks` 項目だけを同期している。これはsettings全体を
symlinkにしない安全策として導入したが、登録の流れを分かりにくくしている。

## 方針

1. `~/.claude/settings.json` の既存 `hooks` を、共通イベント本体の5コマンドへ直接更新する。
2. `~/.claude/agent-hooks -> hooks-registry/` の窓は維持する。
3. `hooks-registry/claude/apply-hooks.py` と `hooks-registry/claude/hooks.json` を削除する。
4. `claude/AGENTS.md` と参照文書を「settings.jsonが登録表」として更新する。settings全体をrepoへコピー・symlinkしない。

## 完了条件（レビュー項目）

- [x] `~/.claude/settings.json` の `SessionStart` / `UserPromptSubmit` / `Stop` / `SubagentStart` /
  `SubagentStop` が、`~/.claude/agent-hooks/events/` の該当Pythonを指す。
- [x] Claudeのhooksコマンド以外の設定値を表示・記録・変更していない。
- [x] `claude/apply-hooks.py` と `claude/hooks.json` がrepoから削除され、現行AGENTS/referencesに参照がない。
- [x] `python3 -m json.tool ~/.claude/settings.json` と `shared/session-board/registered.sh` がPASSする。
