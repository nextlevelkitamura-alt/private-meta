# quality-gate / reviewer 共通指針

reviewer / evaluator / quality-gate を3ツール横断で作るときの共通パターン。`SKILL.md` の読み分けで reviewer 系を作るとき、対象ツールの reference と併せて読む。

## 1. 原則: reviewer は read-only

レビュー専用エージェントに編集・破壊操作をさせない。3ツールとも read-only を徹底する。

1. Claude Code: `tools` を読み取り系（Read / Grep / Glob / Bash）に絞り、編集ツール（Edit / Write）を渡さない。`permissionMode: plan`。
2. Codex: `sandbox_mode = "read-only"`。`approval_policy` は承認を要さない構成に寄せる。
3. OpenCode: `mode: subagent`、`permission` の `edit: deny`。bash は原則 `ask`、破壊コマンドは `deny`。

## 2. 出力フォーマット（3ツール共通）

reviewer の出力は次の型に揃える。

1. Verdict: APPROVED / WARNING / BLOCKED
2. 重要な指摘
3. 必須修正
4. 実行すべきテスト
5. 必要なら、外部レビューが要るか

## 3. 評価観点

1. 正しさ / 回帰バグ / セキュリティ / テスト不足 / 仕様とのズレ / Definition of Done。
2. 評価基準は曖昧にせずファイル化して渡す（特に Codex へ外部レビューを頼むとき）。Claude 側と Codex 側は文脈を自動共有しない。

## 4. ツール別テンプレへのポインタ

具体的な定義ファイルは各ツールの reference のテンプレを使う。

1. Claude Code の quality-gate → `claude-code.md` §11
2. Codex の reviewer → `codex.md` §8
3. OpenCode の go-quality-gate → `opencode.md` §9

## 5. 禁止

1. reviewer に編集・書き込み権限を渡す。
2. `bypassPermissions` / `danger-full-access` / `--auto` 前提の設計。
3. 破壊コマンド（`rm` / `git push` 等）の無条件許可。
