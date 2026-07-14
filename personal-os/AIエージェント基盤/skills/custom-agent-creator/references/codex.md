# Codex カスタムエージェント

Codex 側で「役割を固定した使い方」を作るための reference。`SKILL.md` の読み分けで Codex が対象のとき読む。

注意: 2026-07-10 に codex-cli 0.142.5 の実機で検証済み。かつて本referenceが前提としていた「`~/.codex/agents/<name>.toml` に custom agent を定義する」方式は、このバージョンのCLIには存在しない（ヘルプ・doctor・バイナリ・ディレクトリのいずれにも痕跡なし）。本referenceは実在を確認できた機構だけを扱う。キー・値はバージョンで変わりうるため、実装時に公式ドキュメントで再確認する。

## 目次

1. 実在する3方式と選び方 / 2. カスタムプロンプト / 3. プロファイル / 4. Skill同梱 agents / 5. sandbox_mode / 6. approval_policy / 7. ClaudeからCodexへ委任する（exec + resume） / 8. テンプレート

## 1. 実在する3方式と選び方

1. カスタムプロンプト: `~/.codex/prompts/<name>.md`。対話TUIで `/名前` として呼ぶ役割台本。
2. プロファイル: `codex --profile <name>`（`-p`）。`~/.codex/<name>.config.toml` を base config に層として重ねる設定レイヤ。
3. Skill同梱 agents: Skill / plugin バンドル内の `agents/*.yaml`・`agents/*.md`。配布物にエージェント面を付けるときだけ。

選び方: 人間が対話TUIで使う役割 → 1（設定も変えるなら＋2）。設定だけ変えたい → 2。Skill/pluginとして配布 → 3。**Claude Code から委任する場合はどれも不要**（§7。設定は全部 `codex exec` の引数で渡せる）。

## 2. カスタムプロンプト（~/.codex/prompts/<name>.md）

1. 形式: frontmatter の `description:` ＋ 日本語本文 ＋ 末尾に `$ARGUMENTS`（呼び出し時の引数が入る）。
2. 呼び出し: 対話TUIで `/名前 <引数>`。`codex exec` での展開は未確認（execへは依頼文へ直接書く方が確実）。
3. 向く用途: 人間が手でCodexを起動して使う定型役割（レビュー担当・すり合わせ等）。

## 3. プロファイル（~/.codex/<name>.config.toml）

1. `codex --profile <name>` で base の `~/.codex/config.toml` に重ねる。baseの `mcp_servers` 登録・ログイン状態はそのまま生きる。
2. 書けるキーは config.toml と同じ（`model` / `model_reasoning_effort` / `sandbox_mode` / `approval_policy` / `[mcp_servers.<名前>]` 等）。
3. プロファイル専用にMCPを足したい場合は、このファイルへ `[mcp_servers.<名前>]` を直接書く（`codex mcp add` はglobalのconfig.tomlにしか書けない）。

## 4. Skill同梱 agents

1. `agents/openai.yaml`: Skillの表示・起動メタデータ（`interface:` / `dependencies:`。MCP依存の宣言など）。
2. plugin の `agents/<name>.md`: frontmatter（name / description）＋本文プロンプト。
3. 単体のエージェント定義ファイルとしては使えない（Skill/pluginに同梱する前提）。

## 5. sandbox_mode

1. `read-only`: 調査・レビュー・相談。OSレベルで書き込み不能。
2. `workspace-write`: 作業ディレクトリ内のみ編集可。実装worker向け。
3. `danger-full-access`: 制限なし。新たに指定しない（baseが既にそうなら重ねて書く必要もない）。

CLI指定は `-s <値>`（対話TUI・execの両方で有効）。

## 6. approval_policy

1. 値: `untrusted` / `on-failure`（非推奨）/ `on-request` / `never`。
2. CLI指定 `-a` は対話TUIのみ。**exec に承認経路は無い**: `-a` フラグ自体が無く、`-c approval_policy=on-request` を渡しても承認UIは出ず、sandbox拒否がそのままモデルへ返る（ハングしない・実機確認）。
3. したがって exec の制御は「`never` ＋ sandbox ＋ 依頼文に書く制約」の3点で行う。

## 7. ClaudeからCodexへ委任する（exec + resume）

**既定はメインエージェントが直接 `codex exec` を駆動する**（2026-07-11決定。監督サブエージェントは廃止——優秀なモデルが直接管理する方が粒度の細かい判断を拾える。実践調査でも直接execが多数派・公式原則も「往復が頻繁ならメイン直」）。subagentで包むのは、独立タスクを2本以上並列で走らせ大量ログを隔離したい例外時だけ。以下の手順は両方に共通（2026-07-10 実機検証）。

1. 起動: `codex exec --json -C <作業dir> -o <最終メッセージ用file> "<依頼文>" > <イベントログfile>`。
2. thread_id: イベントログ先頭行 `{"type":"thread.started","thread_id":"<uuid>"}` から取得。
3. 継続: `codex exec resume <thread_id> --json ... "<追加指示>"`。文脈は `~/.codex/sessions/` にディスク永続し、プロセス・セッションの寿命に依存しない。`resume --last` は既定でcwdフィルタあり（`--all` で解除）。
4. read-only委任（相談・レビュー）は `-s read-only` を毎回付ける。
5. inline MCP（`codex mcp-server` 接続）を長時間委任に使わない理由: MCPツール呼び出しはクライアント側の実質10分タイムアウトに支配され、`codex-reply` の threadId はサーバープロセス内のみ有効（再起動後は "Session not found"。ただし同じIDを `codex exec resume` へ渡せば復元できる）。対話的承認（elicitation）が必要な場合だけMCPに優位性がある。
6. 生きた実例: `~/.claude/commands/codex-impl.md`（/codex-impl・メイン直接駆動の手順書）/ `~/.claude/agents/codex-consult.md`（相談役・read-only固定・exec直接駆動）。旧 `codex-implementer` サブエージェントは2026-07-11廃止（メイン直接駆動へ一本化）。
7. 実装×評価ペア（2026-07-11）: ライト以上の実装は、実装=Codex（exec）× 評価=`~/.claude/agents/impl-reviewer.md`（claude系sub・read-only）の異系統クロスチェックで回す。採点と差し戻しは口頭でなくMD駆動（plan.md→評価NN.md→修正NN.md→`exec resume`で「修正NN.mdを読め」）。規約は my-brain/areas/AGENTS.md §3「評価・修正文書」、上限・規模判定は `GLOBAL_AGENTS.md` §7。

## 8. テンプレート: レビュー担当カスタムプロンプト

`~/.codex/prompts/reviewer.md`（人間が対話TUIで使う用。Claudeからの委任は§7の形で依頼文に直接書く）。

```markdown
---
description: 変更差分の正しさ、回帰、セキュリティ、テスト不足を確認するレビュー担当
---

あなたは厳格なコードレビュー担当です。ファイルは編集しないでください。
現在の差分と関連ファイルを確認してください。

重点的に確認すること:
- 正しさ / 回帰バグ / セキュリティリスク / テスト不足 / 仕様とのズレ

出力形式:
1. Verdict: APPROVED / WARNING / BLOCKED
2. 重要な指摘
3. 必須修正
4. 実行すべきテスト

対象・補足: $ARGUMENTS
```

read-onlyで起動する例: `codex -s read-only "/reviewer 直近の差分"`。
