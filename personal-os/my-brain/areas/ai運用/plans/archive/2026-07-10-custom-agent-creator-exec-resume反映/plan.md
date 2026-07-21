# custom-agent-creatorへexec+resume知見を反映

- 起票: 2026-07-10（Codexサブエージェント定義書セッション。実機検証の知見を正本referenceへ反映）
- 対象repo: private-meta（`personal-os/AIエージェント基盤/`）
- 規模: ライト（4ファイル・追記/書き換え中心・戻せる・人間ゲートなし）
- 実装: このセッションの親Claudeが直接（文脈保持のため）

## 背景（2026-07-10実機検証で確定した事実）

- `~/.codex/agents/<name>.toml` のcustom agent機構はcodex-cli 0.142.5に存在しない（ヘルプ・doctor・バイナリstrings・探索で確認）。
- 実在する相当機構は3方式: ①Skillバンドル内 `agents/*.md|*.yaml` ②`codex --profile <name>`（`~/.codex/<name>.config.toml`を層で重ねる）③`~/.codex/prompts/<name>.md`。
- approval_policyの実在値: `untrusted` / `on-failure`(非推奨) / `on-request` / `never`。sandboxは `-s` でexecにも指定可。
- Claude→Codex委任の推奨構成: `codex exec --json`（先頭イベント`thread.started`からthread_id取得）＋`codex exec resume <thread_id>`（`~/.codex/sessions/`にディスク永続・プロセス寿命に非依存）。
- inline MCP（`codex mcp-server`）の制約: MCPツール呼び出しはClaude Code側の実質10分タイムアウト支配下（progress延長仕様なし）、threadIdはサーバープロセス内のみ有効（再起動後"Session not found"・ただし同IDを`exec resume`へ渡せば復元可）。
- execに承認経路は無い（制御は`never`＋sandbox＋依頼文の制約）。
- 生きた実例: `~/.claude/agents/codex-implementer.md` / `codex-consult.md`。

## やること

1. `skills/custom-agent-creator/references/codex.md`【大幅書き換え】: TOML custom agent前提（§1〜3・§8）を実在3方式へ。新節「ClaudeからCodexへ委任する（exec --json＋exec resume）」を追加。approval値に`untrusted`追加。冒頭の注意書きを実機確認済みの記述へ。
2. `skills/custom-agent-creator/references/claude-code.md`【部分更新】: §7 inline MCPへ10分壁・スレッド非永続の注意＋長時間委任はBash経由exec+resume推奨の1文。§10のcodex-consultを「inline MCPで継続相談」から「exec+resume(read-only)で相談」へ。実例2ファイルへの言及を追加。
3. `skills/custom-agent-creator/references/checklist.md`【小更新】: Codex節のTOML前提項目を実在3方式＋exec委任の確認項目へ差し替え。
4. `hooks-registry/references/codex-hooks.md`【小更新】: agents TOML仕様の節に「0.142.5実機では未実装・確認できず」の注記。

## やらないこと

- SKILL.md本文の変更（読み分け・手順は現行のまま成立）
- GLOBAL_AGENTS.md / AIモデル一覧.md への追記（毎回読む全体ルールに作成時知識を入れない）
- catalog / logs の更新（既存スキルの内容修正は更新義務の対象外と2026-07-10に確認済み）
- `~/.claude/agents/` の2ファイル変更（完成済み・本計画の対象外）

## 完了条件（レビュー項目・こうなっていれば正しい）

- [x] codex.md に `~/.codex/agents/*.toml` を実在機構として説明する記述が残っていない（歴史的注記は可）。
- [x] codex.md に exec --json での thread_id 取得と exec resume の実文例があり、approval値4種（untrusted含む）が列挙されている。
- [x] claude-code.md §7 に10分タイムアウトとスレッド非永続の注意があり、§10 の codex-consult が exec+resume 前提になっている。
- [x] checklist.md の Codex 節に TOML 必須・developer_instructions 必須の項目が残っていない。
- [x] codex-hooks.md の該当節に実機未確認の注記が入り、他の節は無変更。
- [x] 変更が上記4ファイル＋本plan.mdに閉じ、パス指定でcommitされている（push無し）。

※ 2026-07-21クローズ儀式で見出し・チェックボックス書式へ正規化（文言は不変）。採点は評価01.md（遡及）。

## 戻し方

- commit単位で `git revert`。
