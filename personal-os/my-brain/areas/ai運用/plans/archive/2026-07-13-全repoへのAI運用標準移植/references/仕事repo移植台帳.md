# 仕事repo移植台帳

親計画: `../program.md` ／ 所有Child: `../plans/03-仕事repo移植台帳.md`

## 監査snapshot

- canonical repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- branch / HEAD: `master@6e0862e53a9392b886511fa4f6e5b07b20f574e4`
- upstream: `origin/master` より ahead 5 / behind 0
- dirty: Gate 0の固定10pathだけ、staged 0
- A01〜A04開始/終了: HEAD・dirty pathとも不変
- 監査制約: read-only、外部API 0、secret値出力 0

## 1. plan実体

canonical discoveryは次の2 globだけに限定する。

1. `領域/**/計画/plan.md`
2. `plans/{planning,active,paused,done}/**/plan.md`

basenameが `plan.md` でない補助文書、`explain/**`、画像、`.gitkeep` はcanonicalにしない。

| # | canonical path | raw state | normalized | 類型 / 正しい箱 | consumer | 判断 / 人間gate |
|---:|---|---|---|---|---|---|
| 1 | `領域/事務/求人作成自動化/計画/plan.md` | 進行中 | active | 領域固有 / 現path | 生成index、task/eod/review | 維持。移動なし |
| 2 | `領域/整備/AI活用/NotebookLMスライド/計画/plan.md` | 計画中 | planning | 領域固有 / 現path | 生成index | 維持。旧broken linkは本文品質warning |
| 3 | `領域/整備/スキル統合/計画/plan.md` | 進行中 | active | 領域固有 / 現path | 生成index | 維持。移動なし |
| 4 | `領域/整備/ディレクトリ再編/計画/plan.md` | 完了 | done | 領域固有 / 現path | 生成index | 現path維持。archiveは別人間判断 |
| 5 | `領域/整備/リポ評価/計画/plan.md` | 進行中 | active | 領域固有 / 現path | repo-eval、W03D、生成index | 維持。一覧直接更新指示だけ修正 |
| 6 | `領域/整備/架電自動化/計画/plan.md` | 進行中 | active | 領域固有 / 現path | 生成index | 維持。外部実行は本移植対象外 |
| 7 | `領域/運用/オペレーションミス改善/計画/plan.md` | 計画中 | planning | 領域固有 / 現path | 生成index | 維持。移動なし |
| 8 | `領域/運用/週次定例/計画/plan.md` | 進行中 | active | 領域固有 / 現path | weekly-deck、生成index | 維持。移動なし |
| 9 | `領域/開拓/法人営業/計画/plan.md` | 進行中 | active | 領域固有 / 現path | 生成index | 維持。外部送信は本移植対象外 |
| 10 | `領域/集客/チャットワーク一斉投稿/計画/plan.md` | 停止済み | paused | 領域固有 / 現path | issei-post、生成index | 維持。再開は明示承認 |
| 11 | `領域/集客/ワーカー検索/計画/plan.md` | Phase 3.1 完了 | active | 領域固有 / 現path | worker-search、生成index | `完了` 部分一致禁止。Phase 4あり |
| 12 | `plans/planning/2026-07-13-circus応募自動入力/plan.md` | bucket=planning | planning | repo横断 / root bucket | 生成index | 維持。bucketを状態源にする |
| 13 | `plans/planning/2026-07-13-haken-mendanスキル軽量化/plan.md` | bucket=planning | planning | repo横断 / root bucket | 生成index | 維持。bucketを状態源にする |
| 14 | `plans/planning/2026-07-13-求人検索スキル/plan.md` | bucket=planning | planning | repo横断 / root bucket | 生成index | 維持。bucketを状態源にする |

### 補助文書6件

以下はcanonical planへ昇格せず、所属planの資料として維持する。

1. `領域/事務/求人作成自動化/計画/2026-06_求人画像差し替え案.md`
2. `領域/事務/求人作成自動化/計画/求人品質評価Skill_引き継ぎ.md`
3. `領域/事務/求人作成自動化/計画/求人品質評価Skill_監督レビュー.md`
4. `領域/事務/求人作成自動化/計画/求人画像ライブラリ運用計画.md`
5. `領域/開拓/法人営業/計画/implementation-prompt.md`
6. `領域/集客/LINE返信/計画/line-skill-evolution-plan.md`

集計は、領域計画folder 17件（canonical 11＋補助6）、root canonical 3件、repo全体20件である。

## 2. header / state parser契約

実在する形式は、通常blockquote、bold blockquote、dash-list、YAML風frontmatter、H2 statusの5形態。root planは状態をbucketから取る。

- interface: `work-plan-index/v1`
- fields: `schema_version, plan_id, source_path, kind, bucket, state, state_raw, title, domain, project, progress, next_action, target_date, updated_at, aliases, warnings`
- state enum: `planning | active | paused | done`
- exact aliases: `計画中→planning`、`進行中→active`、`完了→done`、`停止済み(...)→paused`、既知の `Phase 3.1 完了→active`
- unknown stateは推測せずfail。genericな `完了` 部分一致は禁止
- field aliases: `次のアクション|次アクション`、`最終更新|更新日`
- explicit `plan_id|計画ID` を優先。legacy IDは領域=`work:area:<domain>:<project-path>`、root=`work:repo:<folder-basename>`
- IDとaliasはUnicode NFC、重複でfail。fuzzy matchしない
- `#plan:focusmap` は `external/unresolved`。仕事repo内planへ誤結合しない
- 生成はfixed sort、temp→validate→atomic rename。失敗時は既存indexをbyte不変にする
- index自身のsource linkは全件validate。canonical plan本文内の旧broken linkはwarningとして分離する

## 3. 旧indexとの差

- `計画一覧.md`: 2026-06-26時点、10件
- 欠落: Chatwork停止計画1件＋root planning 3件＝4件
- ワーカー検索: indexは `Phase 3完了`、正本は `Phase 3.1完了`
- source link列がなく、NotebookLMの入れ子path等を一意解決できない
- NotebookLM本文の旧 `.claude/plans/soft-gathering-wreath.md` は不在。index link検査と本文全link検査を混同しない

## 4. consumer graph

### active index reader/writer 11path

| lane | path | 現在 | 移行後 |
|---|---|---|---|
| C03 | `AGENTS.md` | 一覧を入口に使用 | route契約を所有。Child 04単独writer |
| W03D | `方針/介入レベル.md` | L0で一覧更新 | 正本plan更新→生成 |
| W03A | `.agents/skills/task/SKILL.md` | read/write/create、alias生成 | 正本plan更新→生成 |
| W03A | `.agents/skills/eod/SKILL.md` | read/write、schedule alias補完 | 正本plan更新→生成 |
| W03B | `.agents/skills/review/SKILL.md` | read/write | 正本plan更新→生成 |
| W03B | `.agents/skills/business-planning/SKILL.md` | read/write/create | 正本plan更新→生成 |
| W03C | `.agents/skills/repo-eval/SKILL.md` | write案 | 正本plan更新→生成 |
| W03C | `.agents/skills/repo-eval/rubric.md` | index契約 | 生成indexをread-only利用 |
| W03C | `.agents/skills/repo-eval/agents/structure-auditor.md` | index契約 | 生成indexをread-only利用 |
| W03C | `.agents/skills/repo-eval/templates/plan.md.tpl` | 一覧更新template | 正本plan更新template |
| W03D | `領域/整備/リポ評価/計画/plan.md` | 一覧直接更新指示 | 生成index契約へ変更 |

### canonical planへ直接linkするactive 5path

1. `.agents/skills/repo-eval/templates/scorecard.md.tpl`
2. `方針/スキル一覧.md`
3. `.agents/skills/call/workflows/自動実行.md`
4. `.agents/skills/weekly-deck/SKILL.md`
5. `.agents/skills/issei-post/SKILL.md`

この5件はlink先が正しい限り維持し、index経由へ強制しない。active consumer/referenceは合計16path。

### 履歴としてfreeze

1. `scripts/worker-search/HANDOFF.md`
2. `領域/整備/リポ評価/履歴/2026-05-09/scorecard.md`

## 5. AGENTS / CLAUDE ownership

- root: regular `AGENTS.md`、`CLAUDE.md -> AGENTS.md`、`.claude/skills -> ../.agents/skills`。維持
- 6領域: `AGENTS.md -> CLAUDE.md`、regular `CLAUDE.md`。全件逆向き
- 対象: `領域/{集客,売上,開拓,事務,整備,運用}/{AGENTS.md,CLAUDE.md}` と `DEVELOPMENT.md`
- 各regular CLAUDEは固有本文を持つため、1領域ずつlossless変換する
- symlink削除・regular file置換・向き変更は人間gate

## 6. Skill ownership

- `.agents/skills`: 62entry（repo-local directory 57、cross-repo symlink 3、regular file 2）
- cross-repo: `images-generate`、`skill-creator-custom`、`sns-post`
- `images-generate` / `skill-creator-custom`: Claude・Codex・共通ハブへGlobal露出済み
- `sns-post`: Claudeだけ。Codex・共通ハブへ正本からdirect露出し、fresh session発見試験PASS前にrepo symlinkを外さない
- repo-local Skill本文57件とmanualは移植対象外

## 7. hook / loop / runtime

- Global session-board: Codex/Claudeとも5event各1。自動stage/commit/push 0。Daily＋Tursoを所有
- 仕事hook: PostToolUse 5＋Stop 2、Codex/Claude byte-identical、自動stage/commit/push 0
- 注意: TodoWriteは外部API POST、Stop pruneはignored JSON更新、Stop cleanupは一時成果物削除。cleanupへtracked-file削除防止が必要
- Codex trust: current 7 groupに対しtrust section 8。stale `stop:2:0` はfresh session/UI実測まで未確定
- loop: Global 4＋仕事3 loaded、全last exit 0、`loops-registry/verify.py` は7 PASS。loop実装は変更しない
- active仕事runtime plist 3本はcanonical path。worker-search source plist 2本は旧rootだがinstaller renderはcanonical
- docs drift: Claude hook文書のSubagent未適用、session-board文書のreconcile未loadは実runtimeと不一致

## 8. 旧absolute path分類

実測はtracked 56file / 114 occurrence。旧互換path自体は存在しないため、activeだけを修正し履歴を一括置換しない。

### Global active候補2path

1. `personal-os/AIエージェント基盤/skills/sns-post/SKILL.md`
2. `personal-os/AIエージェント基盤/skills/images-generate/references/chatgpt-arc-webbridge.md`

### 仕事repo active Skill候補18path

1. `.agents/skills/biz-mail/SKILL.md`
2. `.agents/skills/circus-job-proposal/SKILL.md`
3. `.agents/skills/claim/workflows/経理-来社後処理.md`
4. `.agents/skills/cleanup/SKILL.md`
5. `.agents/skills/cue-note-send/workflows/compose-message.md`
6. `.agents/skills/entry-check/SKILL.md`
7. `.agents/skills/entry-message/SKILL.md`
8. `.agents/skills/eod/SKILL.md`
9. `.agents/skills/job-update/workflows/求人内容編集.md`
10. `.agents/skills/line-job-campaign/SKILL.md`
11. `.agents/skills/line-job-card/SKILL.md`
12. `.agents/skills/meet/SKILL.md`
13. `.agents/skills/mendan-kanri/workflows/管理表追加.md`
14. `.agents/skills/mendan-kanri/workflows/面談後管理表登録.md`
15. `.agents/skills/morning/SKILL.md`
16. `.agents/skills/next-day-schedule/SKILL.md`
17. `.agents/skills/review/SKILL.md`
18. `.agents/skills/task/SKILL.md`

### launchd source候補

O07は8旧root plistを `__REPO_ROOT__` templateへ直し、render結果とruntimeをsemantic比較する。runtimeが同一なら再登録しない。不一致labelだけ個別人間gateにする。

### 除外

`PROGRESS.md`、handoff、backup、履歴、生成物、`claim/evals/evals.json`、`threads.bak` はactive一括置換に混ぜない。

## 9. 移植対象外

仕事repoの `領域/` 実装、manual、業務code、MCP、DB、LINE/Chatwork送信、候補者情報、稼働loopは移動・複製しない。本programが扱うのは計画制御面、AGENTS/CLAUDE向き、Global Skill露出、hook安全、active旧path、launchd source/runtime整合だけである。

## 10. 後続順序

1. S02/S04/S05でGate 0を閉じる
2. W01契約を固定
3. Child 04 routeとChild 10 W02を別writerで実装
4. W03A/B/C/Dを非重複pathで並列、W04でatomic統合
5. 新規/既存plan E2E
6. O03/O04/O05を非重複pathで実行
7. O06をactive分類単位、O07をlabel単位で直列化
8. Review 1で仕事repo全体を一括評価
