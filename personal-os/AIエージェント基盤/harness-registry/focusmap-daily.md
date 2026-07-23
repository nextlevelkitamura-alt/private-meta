# Focusmap Daily Harness

更新日: 2026-07-23

状態: Codex / Claude共通Hook・分類policy・明示Skillを実装済み。追加DDLは本番Tursoへ適用し、実DBでの書込み・読戻しまで検証済み。Focusmap UI接続は未実施。

このMarkdownは、Focusmap Dailyで「Theme・Plan・単発作業・Claude/Codex session」がどうつながるかを説明する正本である。同名HTMLは人間向け図解であり、AIの実行導線ではない。

## 結論

毎回のUserPromptSubmitで、同じ長いSkill本文を注入しない。

```text
SessionStart
├─ session / runtime / repo / worktree / branchを機械記録
└─ 短い固定分類policyをその開始イベントで注入

UserPromptSubmit（毎回）
├─ turnをpendingとして先に記録
├─ 今日のTheme・Plan候補を取得
└─ 現在地と候補だけを短く注入

メインAI
├─ 仕事の意味を5分類で判断
└─ 専用CLIへproposalを書き戻す

人間
└─ 曖昧なproposalをFocusmapで採用・却下・付け替え
```

Hookは「いつ動くか」、Pythonは「事実と順番」、policy Markdownは「自動分類の短い境界」、Skillは「人間が明示した再分類手順」を所有する。

## Theme・Plan・Session・Skillの関係

ThemeはFocusmapのTursoで管理する「複数Planを束ねられる今日の目的」である。Planの代わりではない。

```text
Workspace / repo表示
└─ Theme（Focusmap / Turso）
   ├─ Theme内作業
   │  ├─ 小さな単発
   │  ├─ Theme全体の計画外修正
   │  └─ Plan候補
   ├─ Plan A（本文・状態の正本はrepo Markdown）
   │  └─ Codex / Claude session
   └─ Plan B
      └─ Codex / Claude session
```

| 単位 | 意味 | 正本 |
| --- | --- | --- |
| Theme | 何の目的を今日は進めるか | Focusmap inbox DB `themes` |
| Plan | どの経路・工程で達成するか | 各repoの計画Markdownと状態フォルダ |
| Session | 誰が、いつ、どこで実行中か | board DB `sessions` と実行Context |
| Skill | どう実行するか | AIエージェント基盤 `skills/` |
| Todo | 人間が完了チェックする単位 | inbox DB `todos` |

Skillを使ったこと自体は単発判定の根拠にしない。たとえば`html` Skillを使っていても、既存Planを進めるならPlan sessionである。

## 何が、どのタイミングで作用するか

### 1. SessionStart

登録済み入口:

```text
hooks-registry/events/session-start/reconcile-and-notify.py
  → shared/session-board/common.py start_register()
  → shared/session-board/routing.py
  → board.py context-upsert
```

行うこと:

- session key、runtime、Git repoまたは非Git folderを判定する
- linked worktreeをGit common-dir由来の同じ`repo_key`へまとめる
- canonical repo path、実際のcwd、branchを分けて記録する
- remote URLやcredentialを読まない・保存しない
- `session-classification-policy.md`をそのSessionStartイベントで追加Contextとして返す

`startup`だけでなく`resume`や`compact`後にもSessionStartが来れば、圧縮で失われた固定方針を戻すため再注入する。毎Promptでは繰り返さない。

SessionStartでは仕事の意味やTheme/Planを確定しない。従来どおり`session`本体の行は最初の意味あるPromptで作るため、開始しただけの幽霊行を増やさない。

### 2. UserPromptSubmit

登録済み入口:

```text
hooks-registry/events/prompt-register/register-and-guide.py
  → shared/session-board/common.py register_prompt()
```

同じPython handler内で順番を保証する。

```text
1. promptを正規化
2. session行を登録またはwait→runへ復帰
3. `route-prepare`を1回呼ぶ
4. repo/worktree Contextとturn pendingを同一DB batchで記録
5. board DBの現在所属を1 pipelineで読む
6. 今日＋対象repoのThemeと、そのThemeが参照するPlanだけをinbox DBの1 pipelineで読む
7. 1つの短いContextをruntimeへ返す
```

同一イベントに別Hookを増やして順番を作らない。Codex・Claudeとも、同一イベントの複数command Hookは並列になりうるためである。

### 3. メインAI

AIが行うこと:

- ユーザーの依頼を理解する
- 明示所属があれば継続する
- 未所属なら5分類のいずれかを提案する
- `board.py route-propose`で対象turnへ書き戻す

AIはSQLを直接書かず、ThemeやPlanを類似だけで自動作成しない。

### 4. SubagentStart / SubagentStop

subagentは親sessionの分類を継承し、Dailyへ独立sessionとして増やさない。agentの開始・終了・状態は既存session-board Hookが機械記録する。

### 5. Stop

Stopは`run → wait`と生存照合だけを行う。Theme/Plan分類、Todo完了、archiveを決めない。

## 実際に注入する内容

### 各SessionStartイベントで

正本:

`hooks-registry/events/prompt-register/session-classification-policy.md`

主な内容:

- Pythonは事実だけを記録し、意味を確定しない
- 明示ID・Planカード・handoff・人間確定済みrouteだけ確定可
- 意味の類似だけならproposal
- Plan / Theme内作業 / Plan候補 / Theme候補 / 未分類の境界
- HookからSkillを自動実行しない
- AIが書き戻せなくてもpendingを残す

### 毎Promptで短く

明示所属がある時:

```text
[FOCUSMAP ROUTING CONTEXT]
turn: <turn-id>
repo: focusmap / main
current: theme=<theme-id> / plan=<plan-slug>
required: 同じ目的なら維持。変わった時だけ再評価。
write-back: board.py route-propose ...
```

未所属の時:

```text
[FOCUSMAP ROUTING CONTEXT]
turn: <turn-id>
repo: focusmap / main
theme候補: <id>=<短い名前> / ...（最大3）
plan候補: <slug>=<短い名前>[active] / ...（最大3）
required: 5分類の1つを判断
write-back: board.py route-propose ...
```

毎Promptへ保存・注入しないもの:

- `SKILL.md`全文
- 生Prompt全文
- Plan Markdown本文
- remote URL
- credential、token、secret
- AIの思考過程

Prompt本文やPrompt由来hashは保存しない。pendingに保存するのはsession/turn/runtimeから作るevent fingerprintと、secret・credential・メール・電話をマスクした80文字以内の要約だけである。

## 分類の5種類

| `route_kind` | 条件 | Focusmapでの扱い |
| --- | --- | --- |
| `plan` | 明示された既存Planの工程・特定Planの手直し | Planカード内のsession |
| `theme_work` | Themeへ直接貢献する小さな単発・Theme全体の障害除去 | Theme直下「テーマ内作業」 |
| `plan_candidate` | 複数工程、複数session、依存、独立評価が必要 | Theme内のPlan候補 |
| `theme_candidate` | 既存Themeと異なる継続目的になりうる | 未分類のTheme候補 |
| `unclassified` | 一回限り、無関係、または判断材料不足 | repo別の未分類 |

自動`accepted`を許す証拠:

1. FocusmapのPlanカードから開始した
2. handoffにTheme/Plan IDがある
3. ユーザーが所属先を明示した
4. 同じsessionで人間がすでに確定した

それ以外は`proposed`のまま人間確認へ送る。

## HookとSkillの違い

### 自動Hook

毎回必ず動く。事実受付と短い現在地の注入を担当する。

### `session-routing` Skill

正本:

`skills/session-routing/SKILL.md`

使う時:

- 「このsessionを分類して」
- 「未分類を整理して」
- 「Theme/Planへの紐付けを見直して」

使わない時:

- 毎Promptの自動受付
- SessionStartの自動記録
- Theme/Planの自動作成
- HookからSkillを強制起動する目的

Codexは`~/.agents/skills/session-routing`、Claudeは`~/.claude/skills/session-routing`から同じ正本へsymlink露出する。`~/.codex/skills`には重複配置しない。

## 実装ファイル地図

```text
AIエージェント基盤/
├─ hooks-registry/
│  ├─ events/session-start/
│  │  └─ reconcile-and-notify.py
│  ├─ events/prompt-register/
│  │  ├─ register-and-guide.py
│  │  └─ session-classification-policy.md
│  └─ shared/session-board/
│     ├─ common.py
│     ├─ routing.py
│     ├─ sanitize.py
│     ├─ board.py
│     ├─ turso/store.py
│     ├─ turso/migrations/20260723_session_routing.sql
│     ├─ tests/test_routing.py
│     └─ tests/test_hook_output.py
├─ skills/session-routing/
│  ├─ SKILL.md
│  └─ SKILL.html
└─ harness-registry/
   ├─ focusmap-daily.md
   └─ focusmap-daily.html
```

runtime登録表は既存のまま使う。

- Codex: `hooks-registry/codex/hooks.json` → `~/.codex/hooks.json`
- Claude: `~/.claude/settings.json`の`hooks`
- 両方とも`agent-hooks/events/...`経由で同じPythonを実行する

出力形式だけが異なる。

| runtime | stdout |
| --- | --- |
| Codex | `hookSpecificOutput.additionalContext` JSON |
| Claude | plain text |

## 追加DB契約

対象migration:

`hooks-registry/shared/session-board/turso/migrations/20260723_session_routing.sql`

既存テーブルをALTERせず、次の2表だけを追加する。

### `session_execution_contexts`

- session key
- runtime
- opaque `repo_key`
- 表示名
- Git / folder
- detected / unregistered
- canonical repo path
- worktree root
- 実際のcwd path
- branch
- first / updated timestamp

### `session_route_proposals`

- session / turn
- runtime / repo key
- session/turn/runtime由来event fingerprint
- マスク済み短い要約
- 5分類またはpending
- Theme / Plan参照
- 短い理由
- pending / proposed / accepted / rejected / superseded

既存データはbackfillしない。新しいSessionStart/UserPromptSubmitからbest-effortで自己修復する。

## 現在の実装状態

| 項目 | 状態 |
| --- | --- |
| Codex SessionStart / UserPromptSubmit共通処理 | 実装済み |
| Codex JSON `additionalContext` | 実装・ローカル検証済み |
| Claude plain text Context | 実装・ローカル検証済み |
| repo/worktree/branch判定 | 実装・fake DB検証済み |
| pending・proposal CLI | 実装・再試行保護とreadbackをfake DB検証済み |
| `session-routing` Skill | 作成・Codex/Claude露出済み |
| 追加DDLファイル | 作成・SQLite構文検証済み |
| 本番TursoへのDDL適用 | 適用済み・追加2表／3 indexと書込み・読戻しを実測済み |
| Focusmap UIからproposal読取・採用 | 未実装（既存program子12〜13） |
| Theme内作業のTodo完了・archive | 未実装（既存program子13） |

本番DBにはmigrationを適用済み。なお別環境でmigrationが未適用でもHook本体は止まらず、既存session-boardは従来どおり動き、routing用書込み・読取りだけbest-effortで空になる。その状態では「分類記録済み」とは扱わない。

## 次の直列実装

既存program `2026-07-17-当日ボードSQL化` の子10〜14で管理する。

1. 子10: 分類契約・policy・明示Skill
2. 子11: Hook順序・repo Context・追加DB
3. 子12: Dailyのrepo selector・Theme内作業UI
4. 子13: 人間採用・Todo・完了・archive・正式Plan化
5. 子14: Codex/Claude・worktree・非Git・DB障害の統合評価

本番DBへDDLを適用する前に、人間へ対象DB・追加2表・既存表非変更を再提示して承認を得る。

## 根拠ファイル

- `../hooks-registry/events/prompt-register/AGENTS.md`
- `../hooks-registry/events/prompt-register/register-and-guide.md`
- `../hooks-registry/events/prompt-register/session-classification-policy.md`
- `../hooks-registry/shared/session-board/common.py`
- `../hooks-registry/shared/session-board/routing.py`
- `../hooks-registry/shared/session-board/board.py`
- `../hooks-registry/shared/session-board/turso/store.py`
- `../hooks-registry/shared/session-board/tests/test_routing.py`
- `../skills/session-routing/SKILL.md`
- `../../my-brain/areas/ai運用/plans/active/2026-07-17-当日ボードSQL化/program.md`
