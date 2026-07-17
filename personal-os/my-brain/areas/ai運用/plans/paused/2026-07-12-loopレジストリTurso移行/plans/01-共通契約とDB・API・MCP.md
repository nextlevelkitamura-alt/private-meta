親計画: ../program.md ／ 分類: loop ／ 種別: 統合整理

# 01 共通契約とDB・API・MCP

## 目的

Turso正本のschema、canonical definition、状態語彙、API/MCP、認証、人間ゲート、fixtureを先に固定し、
Mac担当とUI担当が同じ契約から並列実装できるようにする。

## 現状

- FocusmapのTursoはserver-only singletonで、監視DAOとagent token認証を再利用できる。
- 外部AI向け `/api/v1` はscope付きAPI keyを持つが、loop scopeは未定義。
- 現行MCPはSupabase service role直結の旧構造。loopでは権限過大であり流用しない。
- Turso migration runnerは単一SQL hardcode箇所があり、loop migrationの適用方式を決める必要がある。

## 方針

### DB

1. `loop_definitions`: userごとのstable key、current revision/hash、desired enabled、owner/implementation ref。
2. `loop_definition_revisions`: immutable canonical snapshot。purpose、domain、schedule、timezone、failure policy、ordered steps、log refs、launchd設定を持つ。
3. `loop_runtime_state`: loop×runnerのloaded/process/exit/run count/failure/last-next run/observed revision/hash/observed_at。
4. `loop_runs`: 実行時revision/hash、trigger、start/finish、status、exit、attempt、短いsummary/error、log refs、event id。
5. `loop_audit_events`: actor、action、before/after revision、bounded change、request id。
6. `loop_apply_outbox`: apply/enable/disable要求、承認、claim lease、attempt、result。at-least-once＋revision/hash冪等。

全表は `user_id` を持つ。内部stepは自由Markdown解析でなくcanonical JSON array。definition hashはサーバー側だけで
canonical JSONをSHA-256化する。生ログ・secret・個人情報は保存しない。

### 状態語彙

- 実行: waiting / running / succeeded / failed / disabled。
- 反映: synced / pending_apply / drifted / unapplied。
- Mac: online / offline / unregistered。
- 総合: healthy / attention / stoppedは上記から決定的に派生し、launchd `not running` はwaitingとして扱う。

### API

- 外部AI: `/api/v1/loop-registry`。`loops:read` / `loops:write` / `loops:apply` scope。
- Mac Agent: `/api/agents/loop-registry`。agent tokenからuser/runnerを確定。
- `GET contract/list/get/runs/drift`。
- `POST/PATCH definition` は `expected_revision` と `mutation_id` 必須。
- apply requestは要求作成まで。approveはSupabase JWT/cookieの人間UIだけに許す。
- observation/run eventは `event_id` 冪等。outbox claimはlease＋target user/runner/revision照合。

### MCP

`get_contract`、`list_loops`、`get_loop`、`get_runs`、`get_drift`、`update_definition`、`request_apply`。
MCPはFocusmap APIをHTTPで呼び、Turso・service roleへ直結しない。direct SQL、approve、enable、run-nowは持たせない。

### 共通成果物

- JSON Schemaまたは同等のshared type。
- API response / error / cursor / fixture 7本。
- migration SQLとDAO。
- MCPとUIが参照するcontract version。
- `docs/CONTEXT.md` の正本境界・writer ownership更新。

## 触る候補

- `db/turso/migrations/*_loop_registry.sql`
- `src/lib/turso/loop-registry.ts`
- `src/lib/loop-registry/{schema,canonical-hash,contract}.ts`
- `src/app/api/v1/loop-registry/**`
- `src/app/api/agents/loop-registry/**`
- `src/lib/api-scopes.ts`、`src/app/api/v1/capabilities/route.ts`
- `mcp/src/api-client.ts`、`mcp/src/tools/loops.ts`、`mcp/src/index.ts`
- `docs/CONTEXT.md`

## 完了条件（レビュー項目）

- [ ] migrationが再実行可能で、6tableのkey/index/foreign key/user境界が明示されている。
- [ ] interval/calendar、RunAtLoad、KeepAlive、Throttle、retry、ordered stepsをcanonical schemaで表現できる。
- [ ] server側hashが同じ定義から常に同値を返し、step順またはschedule変更で必ず変化する。
- [ ] stale `expected_revision` は409、同じmutation/event再送でrevision/run/outboxが重複しない。
- [ ] definition revision、current pointer、audit、outboxがtransaction/batchで整合し、中途状態を残さない。
- [ ] read/write/apply scope、Web人間承認、Mac agentの権限が分離され、user越境できない。
- [ ] MCPにTurso token・Supabase service role・direct SQL・approve toolが存在しない。
- [ ] 7loop fixtureがschemaを通り、後続02/03が同じfixtureを参照できる。
- [ ] `docs/CONTEXT.md` にwriter、API、Turso、MCP、認証境界が反映されている。
