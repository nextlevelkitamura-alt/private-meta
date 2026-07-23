# prompt-register — 毎入力を受付し、現在のTheme / Plan候補を短く渡す

runtime の `UserPromptSubmit` で `register-and-guide.py --runtime <claude|codex>` を実行する。
未登録ならボード行を作り、⏸なら🟢へ戻し、「今」が空ならマスク済み入力冒頭を仮置きする。さらに同じhandler内でrepo Contextを自己修復し、turnを`pending`で先に記録してから、現在所属または今日のTheme / Plan候補を短いpacketとして注入する。

## 分類の直列順序

```text
入力正規化
→ session登録・復帰
→ route-prepare（Context upsert＋turn pendingを同一batch）
→ 今日＋対象repoのTheme/Plan候補を各DB1 pipelineで取得
→ 1つのadditionalContext
```

同一イベントに分類用handlerを増やさない。複数command hook間の順序へ依存せず、この1本の中で順番を保証する。

固定分類方針の正本は `session-classification-policy.md`。これはSkillではなく、各SessionStartイベントでplain contextとして読むruntime policyである。resume/compact後は方針を戻すため再注入されるが、毎Promptでは全文を繰り返さず、`[FOCUSMAP ROUTING CONTEXT]`だけを返す。

`.py` の入出力・副作用は [register-and-guide.md](register-and-guide.md) を読む。状態・分類packetのロジックは `../../shared/session-board/common.py`、repo/worktree判定は `routing.py` が正本で、このフォルダには複製しない。

Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json` から、この `.py` を `--runtime` 付きで呼ぶ。`.py` を変える前に同名 `.md` を更新し、runtime別の実装コピーは作らない。
