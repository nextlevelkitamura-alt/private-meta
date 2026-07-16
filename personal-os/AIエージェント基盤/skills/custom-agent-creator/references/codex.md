# Codex カスタムエージェント

Codex 側で「役割を固定した使い方」を作るための reference。`SKILL.md` の読み分けで Codex が対象のとき読む。

注意: 2026-07-15にローカルで `codex --version` を実行し、`codex-cli 0.144.1` を確認した。現行の公式ドキュメントでは、個人用は `~/.codex/agents/<name>.toml`、project用は `.codex/agents/<name>.toml` に1 agent 1ファイルのTOMLを置く。必須キーは `name` / `description` / `developer_instructions`。CLI・schemaは変わりうるため、作成・露出の直前に **`codex --version` と公式の「Subagents」** を再確認する。runtime設定や露出はこのreferenceだけで実行しない。

## 目次

1. 現行の4方式と選び方 / 2. カスタムagent TOML / 3. カスタムプロンプト / 4. プロファイル / 5. Skill同梱metadata / 6. sandbox_mode / 7. approval_policy / 8. ClaudeからCodexへ委任する（delegate + exec + resume） / 9. テンプレート

## 1. 現行の4方式と選び方

1. カスタムagent: `~/.codex/agents/<name>.toml` または `.codex/agents/<name>.toml`。Codexがspawnする役割を定義する。
2. カスタムプロンプト: `~/.codex/prompts/<name>.md`。対話TUIで `/名前` として呼ぶ台本。
3. プロファイル: `codex --profile <name>`（`-p`）。`~/.codex/<name>.config.toml` をbase configに層として重ねる設定レイヤ。
4. Skill同梱metadata: Skill / pluginの表示・起動メタデータ。Codexのcustom agent TOMLの代替ではない。

選び方: Codexがspawnする役割 → 1。人間が対話TUIで使う台本 → 2。設定だけ変えたい → 3。Skill/pluginの表示・起動面 → 4。**Claude Codeからのharness委任は、Task Packetとdelegateを正本にし、agent TOMLの存在を前提にしない**（§8）。

## 2. カスタムagent（~/.codex/agents/<name>.toml / .codex/agents/<name>.toml）

1. 1ファイルにつき1 agent。必須キーは `name`、`description`、`developer_instructions`。ファイル名はnameと合わせるのが分かりやすいが、識別子の正本は `name`。
2. `sandbox_mode`、`model`、`model_reasoning_effort`、`mcp_servers`、`skills.config` など対応するconfig keyも書ける。省略時は親sessionの設定を継承する。
3. reviewer / explorerは `sandbox_mode = "read-only"`、implementerはTask Packetとworktree分離がある時だけ `workspace-write` を選ぶ。モデルID、Task固有の作業場所・branch・背景を定義へ固定しない。
4. global / projectの露出・trust変更は人間承認後だけにする。正本をruntime側で編集せず、registry側から露出する。

最小例:

```toml
name = "reviewer"
description = "完了条件と差分を実物で照合する read-only reviewer。"
sandbox_mode = "read-only"
developer_instructions = """
役割の正本を読んでから、自己申告ではなく実物を根拠に PASS / FAIL / 対象外を返す。編集しない。
"""
```

## 3. カスタムプロンプト（~/.codex/prompts/<name>.md）

1. 形式: frontmatter の `description:` ＋ 日本語本文 ＋ 末尾に `$ARGUMENTS`（呼び出し時の引数が入る）。
2. 呼び出し: 対話TUIで `/名前 <引数>`。`codex exec` での展開は未確認（execへは依頼文へ直接書く方が確実）。
3. 向く用途: 人間が手でCodexを起動して使う定型役割（レビュー担当・すり合わせ等）。

## 4. プロファイル（~/.codex/<name>.config.toml）

1. `codex --profile <name>` で base の `~/.codex/config.toml` に重ねる。baseの `mcp_servers` 登録・ログイン状態はそのまま生きる。
2. 書けるキーは config.toml と同じ（`model` / `model_reasoning_effort` / `sandbox_mode` / `approval_policy` / `[mcp_servers.<名前>]` 等）。
3. プロファイル専用にMCPを足したい場合は、このファイルへ `[mcp_servers.<名前>]` を直接書く（`codex mcp add` はglobalのconfig.tomlにしか書けない）。

## 5. Skill同梱metadata

1. `agents/openai.yaml`: Skillの表示・起動メタデータ（`interface:` / `dependencies:`。MCP依存の宣言など）。
2. Skill / plugin metadataとcustom agent TOMLは別物である。役割をCodexがspawnする目的では、§2のTOMLを使う。
3. 配布形式・対応キーは更新されうるため、作成時にローカルversionと公式ドキュメントを確認する。

## 6. sandbox_mode

1. `read-only`: 調査・レビュー・相談。OSレベルで書き込み不能。
2. `workspace-write`: 作業ディレクトリ内のみ編集可。実装worker向け。
3. `danger-full-access`: 制限なし。新たに指定しない（baseが既にそうなら重ねて書く必要もない）。

CLI指定は `-s <値>`（対話TUI・execの両方で有効）。

## 7. approval_policy

1. 値: `untrusted` / `on-failure`（非推奨）/ `on-request` / `never`。
2. 現行CLIでは `codex exec --help` にも `-a` / `--ask-for-approval` がある。ただしnon-interactive実行は新しい承認を対話的に回収できないため、承認が必要な操作は失敗として親へ返る前提にする。
3. したがって無人delegateの制御は「適切なapproval policy＋sandbox＋Task Packetの制約」の3点で行う。runtimeのグローバル設定をこの目的だけで変えない。

## 8. ClaudeからCodexへ委任する（delegate + exec + resume）

**既定は `agents-registry/harness/delegate.py` が Task Packet / run manifestを生成して `codex exec` を駆動する。** `/codex-impl` はこのdelegateへの互換入口であり、CLI引数やadapterの詳細をコマンド本文へ複製しない。delegateが未導入の互換経路だけ、以下のexec/resume知見を使う。

1. 起動: `codex exec --json -C <作業dir> -o <最終メッセージ用file> "<依頼文>" > <イベントログfile>`。
2. thread_id: イベントログ先頭行 `{"type":"thread.started","thread_id":"<uuid>"}` から取得。
3. 継続: `codex exec resume <thread_id> --json ... "<追加指示>"`。文脈は `~/.codex/sessions/` にディスク永続し、プロセス・セッションの寿命に依存しない。`resume --last` は既定でcwdフィルタあり（`--all` で解除）。
4. read-only委任（相談・レビュー）は `-s read-only` を毎回付ける。
5. inline MCP（`codex mcp-server` 接続）を長時間委任に使わない理由: MCPツール呼び出しはクライアント側の実質10分タイムアウトに支配され、`codex-reply` の threadId はサーバープロセス内のみ有効（再起動後は "Session not found"。ただし同じIDを `codex exec resume` へ渡せば復元できる）。対話的承認（elicitation）が必要な場合だけMCPに優位性がある。
6. 生きた正本: `agents-registry/claude/commands/codex-impl.md`（delegate互換入口）/ `agents-registry/claude/agents/codex-consult.md`（相談役・read-only固定）。runtime露出先の本文を正本にしない。
7. 実装×評価ペア（2026-07-11）: ライト以上の実装は、実装=Codex（exec）× 評価=`~/.claude/agents/impl-reviewer.md`（claude系sub・read-only）の異系統クロスチェックで回す。採点と差し戻しは口頭でなくMD駆動（plan.md→評価NN.md→修正NN.md→`exec resume`で「修正NN.mdを読め」）。規約は my-brain/areas/AGENTS.md §3「評価・修正文書」、上限・規模判定は `GLOBAL_AGENTS.md` §7。

## 9. テンプレート: レビュー担当カスタムプロンプト

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
