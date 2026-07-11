# agents-registry

Claude Code のカスタムエージェント（`~/.claude/agents/`）とコマンド（`~/.claude/commands/`）の正本を置く場所。runtime側は露出先（symlink）であり、正本にしない（GLOBAL_AGENTS の symlink露出原則に従う。2026-07-11新設）。

## 構成

- `claude/commands/` … コマンド正本（`/名前` で発動する手順書。本文はメインの文脈に注入される）
- `claude/agents/` … カスタムエージェント正本（frontmatterのdescriptionで発動判断される別文脈のサブエージェント）

露出は `~/.claude/commands/<名前>.md` / `~/.claude/agents/<名前>.md` からの symlink。本文コピーは禁止。

## 登録一覧

- `claude/commands/codex-impl.md` … Codex実装委任（計画→実装→評価→修正のMD駆動ループ・メイン直接exec駆動）。2026-07-11。
- `claude/agents/impl-reviewer.md` … 実装後の評価担当（レビュー項目×diff採点・read-only）。2026-07-11。
- `claude/agents/codex-consult.md` … Codex相談役（exec直接駆動・read-only固定）。2026-07-10。

## 追加・変更の手順

1. 正本をここに作成・編集する（設計知見は `../skills/custom-agent-creator/references/` を参照）。
2. runtime へ symlink を張る: `ln -s <正本> ~/.claude/{commands|agents}/<名前>.md`。
3. この AGENTS.md の登録一覧に1行追記する。
4. 削除は skill-delete と同様に人間承認＋一覧から除去＋symlink撤去をセットで行う。

## 置かないもの

- 他ツール由来の野良コマンド（`~/.claude/commands/` に残る旧実体ファイル群は legacy。移す時は1件ずつ人間確認）。
- Skill本文（`../skills/` が正本）・hook（`../hooks-registry/`）・secret。
