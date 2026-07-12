---
name: orca-cockpit
description: Orca CLIで「実装 / レビュー」を既定2ペインとする分割コックピット(計画+監督は計画未成熟時のみの任意3ペイン目)を最速で構築・駆動するSkill。worktree作成→画面分割→エージェント(claude/codex/opencode)起動→プロンプト注入(起動引数へ畳み込み送信レース無し)→見張り番(watch.sh)による節目検知までの決定的部分をscripts/cockpit.shで実行し、判断と指示内容は人とAIが持つ。既存repoへ1ペインを高速起動するspawn(--no-mcp)も持つ。使用場面はOrcaで実装+レビューを並行駆動, 複数ペインでエージェント起動, コックピット構築, Orca分割立ち上げ, 中間指揮官を1ペインで立てる。
---

> ⚠️ **要・作り直し（2026-07-04 記）** — LINE通知と cockpit状態フックを整理する方針転換により、`~/.claude/settings.json` の `AGI_COCKPIT_*` 状態書き込みフック（および Codex 側 `~/.agi-tools/codex-notify.sh`）を撤去。本Skillが前提とする「status file 経由の `watch.sh` 状態検知」は現状インエフェクティブ。**新しいコックピット/監督方式を確定してから、本Skill本文と登録スニペットを作り直すこと。** それまでは現状維持（削除しない・参照専用）。

# orca-cockpit

Orca上に「実装(右上) / レビュー(右下)」を既定2ペインとする分割コックピットを最速で立て、各ペインでエージェントを動かして人（指揮官）と見張り番(`scripts/watch.sh`)が監督するSkill。左(計画+監督)は計画未成熟・現場判断が多い場合のみの任意枠。決定的な構築・駆動は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/orca-cockpit/scripts/cockpit.sh` が担う。判断・指示内容・矛盾検知は人とAIが持つ。

## 1. 役割

1. Orcaの分割コックピット（worktree＋3/4ペイン）を構築する。
2. 各ペインでエージェント（claude / codex / opencode）をモデル・effort指定で起動する。
3. 各ペインに議論型プロンプトを注入し、人が介入しながら監督する。
4. 対象外: タスクの入口判断（規模・経路・起動形・モデル。規模語彙の正本は運用契約§2）は `plan-triage`、引き継ぎ書・別チャット用プロンプトの生成は `handoff-plan-supervisor` が持つ。本Skillはその実行機構。

## 2. 既定ルール（固定・上書きは引数）

1. 既定コックピット＝2ペイン: 右上=実装(codex gpt-5.5 medium) / 右下=レビュー(codex gpt-5.5 medium)。左(計画+監督/claude)は任意の3ペイン目（`--pane` を3つ明示指定すれば `up` で起動できる）。使うかどうかの判断基準は `cockpit-supervisor` Skillを見る。
2. worktree表示名（display-name）＝計画名を必ず入れる。branch名は英小文字・ハイフンのみ。
3. ペイン個別の恒久タイトルは付かない（codexがcwd basenameで上書きするため）。役割は「位置」で固定＝左 / 右上 / 右下。
4. 4ペインtemplate: 左上=計画 / 左下=監督 / 右上=実装 / 右下=レビュー。
5. エージェントは並列起動（逐次待ちしない）。3ペイン構築は目安 約9秒。
6. codex更新プロンプトは自動Skip。更新が出た回だけ4つ目の端末で `codex update` を自動実行（走行中セッションは無停止）。無効化は `up --no-update`。

## 3. 手順

0. 構成確認: 3ペイン目（計画+監督）の要否判断は `cockpit-supervisor` Skillを見る。使うと決めたら `scripts/cockpit.sh plan …` で構成カードを人間に提示しOKを取る。
1. 構築: `scripts/cockpit.sh up --repo <name> --branch <english> --title "<計画名>"` を実行（既定＝codex×2で実装/レビューの2ペイン、左は空slot）。役割・モデルを変えるなら `--pane "役割:kind[:model[:effort]]"` を渡す（3ペインにする場合は計画/実装/レビューの3つを明示指定）。
2. 指示注入: 各ペインに議論型プロンプトを送る。`up` と同時なら `--prompt "計画=…"`、後からなら `scripts/cockpit.sh send --terminal <handle> --prompt "…"`。プロンプトはSkill名の指定でもよい。
3. 監督: `scripts/cockpit.sh status --worktree <path>` と `orca terminal read` で進捗確認。ズレは `send` で是正。人の判断が要る所は `orca orchestration gate-create` で止める。
4. 片付け: レビュー合格・反映後に `scripts/cockpit.sh down --worktree <path>` で撤去（端末停止＋worktree削除・人間ゲート）。

## 4. 読み込み方針

1. まずこの `SKILL.md` だけ読む。
2. 起動法・モデル指定・引数の細部は `scripts/cockpit.sh help` を見る（別mdに二重化しない）。
3. 対象repo / branch / 計画名が曖昧なら、推測せず短く確認する。

## 5. エージェント指定

1. `claude`: 計画+監督向け（対話・介入しやすい）。`--model` は任意。
2. `codex`: 実装・レビュー向け。既定 `gpt-5.5` / effort `medium`。`--model` / `--effort` で変更。
3. `opencode`: 将来対応（契約後）。`scripts/cockpit.sh` の `cmd_agent` case に1ブロック追加するだけ。

## 6. レシピ（この時はこれを実行する）

短い早見表。詳細な引数は `scripts/cockpit.sh help`。プロンプトは起動引数へ畳み込むため送信レース（プロンプトのzsh流出）が構造的に起きない。

1. **中間指揮官を1人立てる（既存repoに1ペイン）** → `spawn --no-mcp`。
   例: `cockpit.sh spawn --worktree name:仕事 --title "中間指揮官3" --model claude-sonnet-5 --prompt-file <起動プロンプト.md> --owner 全体管理者A --no-mcp`
   （MCP無効で最速起動。agent出現を確認してから返る）。
2. **実装＋レビューを並行で回す（レーン新設）** → `up`（worktree作成＋2ペイン）。
   例: `cockpit.sh up --repo <name> --branch <english> --title "<計画名>" --owner <指揮官> --pane "実装:claude:claude-sonnet-5" --pane "レビュー:codex:gpt-5.5:high" --prompt "実装=<指示>"`。
   重いMCPで起動が遅いrepoなら `--no-mcp` を足す。
3. **MCP（LINE/Sheets/Playwright等）が要る作業** → `--no-mcp` を付けない（既定でMCP読込）か、`--no-mcp`で立てた後に必要になったらペイン内で `/mcp` で後付け接続する。
4. **緊急で1ペインだけ欲しい** → `spawn` 1行（上の1と同じ・`--no-mcp`推奨）。片付けは `orca terminal stop` かレーンごと `down`。

補足: `spawn` は起動プロンプトを `state/prompts/` へ保存し、ペイン台帳 `state/panes.jsonl` に1行残す（見張り番=keeperがペイン単位の生死・停滞を読む正本）。`send` は送信先worktreeにagentが居ないと送信を拒否する（zsh流出防止・`--force`で上書き）。

## 7. 安全方針

1. 副作用レベル: L2（worktree作成・端末起動・agent起動）。
2. 破壊的操作（worktree削除・branch削除・push・main反映）は人間ゲート。
3. secret / `.env` / 認証値を、プロンプト・ログ・run表示に書かない。
4. 実装フェーズの実行は、各ペインのagentが対象repoのAGENTS・安全ゲートに従う。
5. `scripts/cockpit.sh` は決定的処理のみ。判断・指示内容はAI / 人が持つ。

## 8. 出力

1. `scripts/cockpit.sh up` はJSON（worktree path＋各ペインhandle＋役割位置）を返す。
2. AIはそのhandleで `send` / 監督に繋ぐ。

## 9. 関連

1. 上位・連携: `plan-triage`（入口判断）/ `handoff-plan-supervisor`（引き継ぎ書・別チャット用プロンプト）。本Skillはその「Orca実行機構」。
2. 設計整合: `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-01-スキル実行オーケストレーション/`（分配設計と食い違わせない）。
3. 正本: `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/done/2026-07-02-状態と記録の統合設計/plans/10-cockpit監督の自動ウェイク.md`（方針1〜11）／`/Users/kitamuranaohiro/Private/personal-os/説明書/運用契約.md` §2・§7。
4. 依存: orca CLI, python3, 各agent CLI（claude / codex / opencode）。
5. 判断・監督層: `cockpit-supervisor`（同リポジトリ `skills/cockpit-supervisor/SKILL.md`）。見張り番WAKE時の判断手順・構成カードの要否判断・差し戻し上限などの「判断」は本Skillではなくそちらが正本（方針2・9: 機構=本Skill／判断と監督=`cockpit-supervisor`）。

## 10. 見張り番・権限配布（機構）

1. 見張り番（`scripts/watch.sh <worktree-path> [<worktree-path> ...]`）: 複数worktreeを1本で監視し、error即／人間確認待ちマーカー即／権限確認待ち約2分継続／全ペインidle約4分継続／busy約25分継続（ハートビート・異常ではない）／3時間タイムアウトの5種でexitし、検知理由1行を返す。判断はしない（grepと時計だけ）。**通知つき背景タスク**として起動する（シェルの`&`では終了通知が来ず自動起床しない）。
2. 役割別権限: `up` が worktree に `.claude/settings.json`（`defaultMode: acceptEdits` ＋ orca/git読取allowlist ＋ push/merge/削除/`.env`読取deny、`bypassPermissions`不使用）を配る。既存があれば自動スキップ・`perm --force` で明示上書き。**グローバル設定（`~/.claude`, `~/.codex`）は絶対に触らない**。worktreeのcwdは全ペイン共有のため、この1枚に実装(編集自動許可)とレビュー/監督(読取)の権限を統合している。
3. 役割プロンプト: 起動時のペイン投入プロンプトは `references/role-prompts.md` の定型に従う（制約・状態マーカー標準・報告様式・合成データ原則）。
4. 起床時の判断手順・構成カードの要否判断・見張り番の生存確認と再起動・完了判定の基準は本Skillの対象外。判断と監督は `cockpit-supervisor` Skillを見る。
