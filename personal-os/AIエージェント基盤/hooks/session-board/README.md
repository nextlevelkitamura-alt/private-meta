# hooks/session-board — セッション宣言型ボードの機構

当日デイリー2節ボード（`## 動いているエージェント` / `## 終わったこと`）を駆動する一式。
**skillは廃止**（2026-07-05）。手順md・エンジン・受け口すべてここが正本。

## 構成

- フォルダ構成・共有/分離の正本は `AGENTS.md`（このフォルダ）。ここでは重複させない。
- 対のルール: 受け口 `.py` と手順 `.md` は**同名・拡張子違い**。対の無いもの（`board.py`・`prompt-register.py`・`milestone.md`・template）は単独名。
- `registered.sh` は診断用（唯一の `.sh`・launchctl/grep が本業）。

## 動作モデル（毎ターン確認は廃止・節目だけ確認）

1. **登録**（UserPromptSubmit / prompt-register.py）: 最初のプロンプトで「動いているエージェント」へ🟢1行を機械登録。⏸の行は次プロンプトで🟢復帰。
2. **状態flip**（Stop / session-end.py）: 応答終了で🟢→⏸へ機械flip。**ブロックしない**（毎ターンの往復ゼロ）。
3. **節目確認**（Stop / prompt型 milestone.md）: Haikuが毎回「大目標達成＋満足の気配か」を判定。
   - 未達 → `{"ok":true}`（普通に停止・確認なし）
   - 節目 → `{"ok":false,"reason":"完了報告手順を実行せよ"}` → session-end.md の①②③が注入される
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
  プロンプト送信でも🟢に戻さない（サブ完了までエージェントが `flip --state run` で戻す）。
- ⏸ **停止・確認待ち**（wait）… 手が空いた。次プロンプトで🟢復帰。

`session-end.py`（Stop）は `run` のときだけ⏸へflip（`sub`/`wait`は触らない）。
`prompt-register.py` は `wait` のときだけ🟢復帰（`sub`は触らない）。よって sub は board.py に追加するだけで
既存受け口が自然に維持する（2026-07-05）。

## Claude Code 登録スニペット（登録は人間ゲート）

`~/.claude/settings.json`（絶対パスは実機に合わせる）:

```json
{ "hooks": {
  "SessionStart":     [{ "matcher":"startup|resume|clear|compact",
    "hooks":[{"type":"command","command":".../claude/session-start.py","timeout":10}] }],
  "UserPromptSubmit": [{ "matcher":"",
    "hooks":[{"type":"command","command":".../claude/prompt-register.py","timeout":10}] }],
  "Stop": [
    { "matcher":"", "hooks":[{"type":"command","command":".../claude/session-end.py","timeout":10}] },
    { "hooks":[{"type":"prompt","prompt":"<claude/milestone.md の内容>"}] }
  ]
}}
```

## ガード（登録・作用しないもの）

- `AIJOBS_RUN` 非空（headless）／ session id が `agent-*`（subagent）／ transcript が `*/subagents/*`。

## テスト用 env

- `GOAL_BASE`（デイリー基点）／ `SESSION_BOARD_DATE`（YYYY-MM-DD）／ `SESSION_BOARD_TEMPLATE`。

## 既知の制約

- 強制終了（ウィンドウkill）では Stop が走らず🟢が残る → 掃引は朝夜会。
- 日付跨ぎで前日の⏸行が残る → 掃引は朝夜会。
- 節目判定はHaiku依存＝確率的。迷ったら素通し設計で「聞かなさすぎ」に倒す。
- Codex接続（codex/）は実装・登録・trust 済み（開始🟢/Stop⏸ 実測PASS・サブ🔵自動は未実測）。board.py と手順md は runtime非依存で共用。詳細は `codex/AGENTS.md`。

計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-04-セッション宣言型ボードとplans規約/plan.md`
