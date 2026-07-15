# Codex実装指示書 — 計画立案・実行・完了基盤の再設計

あなたは `nextlevelkitamura-alt/private-meta` の実装担当Codexです。

目的は、現在の計画運用を、**計画を作る → Taskへ分割する → Claude/Codexへ委譲する → worktreeで実装する → 異系統レビューする → plan/programを同期する → 理由付きで閉じる**という一貫した仕組みにすることです。

Orcaを既定経路にしないでください。既存Orca資産は削除せず、任意アダプターとして残してください。

---

## 1. 最初に読む順番

1. `personal-os/AGENTS.md`
2. `personal-os/AIエージェント基盤/AGENTS.md`
3. `personal-os/AIエージェント基盤/GLOBAL_AGENTS.md`
4. `personal-os/my-brain/areas/AGENTS.md`
5. `personal-os/my-brain/areas/ai運用/AGENTS.md`
6. `personal-os/AIエージェント基盤/skills/plan-triage/SKILL.md`
7. `personal-os/AIエージェント基盤/skills/plan-ops/SKILL.md`
8. `personal-os/AIエージェント基盤/skills/handoff-plan-supervisor/SKILL.md`
9. `personal-os/AIエージェント基盤/hooks-registry/AGENTS.md`
10. `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/AGENTS.md`
11. `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/{common.py,session-start.md,session-end.md,README.md}`
12. `personal-os/AIエージェント基盤/agents-registry/AGENTS.md`
13. `personal-os/AIエージェント基盤/agents-registry/claude/commands/codex-impl.md`
14. `personal-os/AIエージェント基盤/agents-registry/claude/agents/impl-reviewer.md`
15. `personal-os/my-brain/areas/ai運用/plans/planning/2026-07-13-完了判定とアーカイブ運用/`
16. `personal-os/my-brain/areas/ai運用/plans/planning/2026-07-08-並列実装フロー/plan.md`

作業前に `git status --short`、現在branch、HEADを確認してください。既存の未コミット変更を巻き込まないでください。

---

## 2. 最重要の現状認識

現在、`plans/active/`を監視して計画を自動実行するエンジンはありません。

現行経路は主に次です。

```text
session-board注入
→ kickoff
→ plan-triage
→ plan-ops scaffold / bucketctl
→ /codex-impl または手動handoff
→ codex exec
→ impl-reviewer
→ 評価/修正
→ 手動の計画・Program更新
→ session-end
```

今回、最後の手動更新を決定的な機械手続きに変えます。

---

## 3. 正本計画

新しい重複Programを作らないでください。

次を今回の親計画として拡張してください。

```text
personal-os/my-brain/areas/ai運用/plans/planning/
2026-07-13-完了判定とアーカイブ運用/
```

内容を「計画立案・実行・完了基盤」の全体Programへ広げます。

フォルダ名の変更は人間ゲートです。最初の実装commitでは移動・改名しないでください。必要なら本文タイトルと子計画を先に更新し、rename案を人間へ提示してください。

次の既存計画は先行資料として取り込みます。

```text
personal-os/my-brain/areas/ai運用/plans/planning/
2026-07-08-並列実装フロー/plan.md
```

新しい終了区分が完成し、人間確認を得た後だけ、`終了区分: merged`として後継Programを記録してarchive候補にしてください。

---

## 4. 非目標

- Orca資産の削除
- 全areaの一括破壊的移行
- 過去計画の一括改名
- 全archiveを自動修正
- Hookによる意味推測
- Hookからの直接的なplan/program編集
- 固定モデルIDを計画本文へ埋め込む
- カスタムエージェントへ固定worktreeを設定する
- 未確認のClaude CLIフラグを決め打ちする
- hook登録、symlink変更、Codex trustを無断で適用する
- push、main反映、本番変更

---

## 5. 目標構成

### Area

```text
areas/<area>/
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
└── plans/
```

- `identity.md`の目的・判断基準・置くもの・置かないものはAGENTSへ統合する。
- `知識/`は必須構成から外す。
- 計画固有資料は `<計画>/references/` を既定にする。
- 既存identity/知識の削除・移動はpilotと人間確認後。

### 単発Plan

```text
<plan>/
├── plan.md
├── references/
├── explain/
├── 評価NN.md
└── 修正NN.md
```

### Program

```text
<program>/
├── program.md
├── plans/
│   ├── NN-子計画.md
│   ├── NN-子計画-評価NN.md
│   └── NN-子計画-修正NN.md
├── references/
├── explain/
└── 終了記録.md
```

`workers/`、`runs/`、`worktrees/`、`ops/`、`queue/`は計画配下に作らないでください。

---

## 6. PlanとProgramの判定

### サクッと

- 変更1〜2ファイル
- 容易に戻せる
- 人間ゲートなし

全YESだけ計画なし。

### 単発Plan

- 主成果1つ
- 主担当1人
- merge/rollback単位1つ
- 原則直列
- 1つの評価で閉じられる

### Program

次のいずれか。

- 独立実行・commit・mergeできる成果が2つ以上
- write laneが2つ以上
- 複数repoに別handoffがある
- 共有契約の後に複数Waveへ分かれる
- 人間ゲートまたはrollback単位が別
- 一人のworkerに渡す変更範囲として広すぎる

ファイル数だけではProgram化しないでください。AIが単発を選ぶ余地を残し、`形態判定`と理由を1行記録してください。

---

## 7. テンプレート変更

対象:

```text
personal-os/AIエージェント基盤/skills/plan-ops/templates/
```

### plan.md / 子計画.md に追加

- `規模`
- `形態判定`と理由
- `非対象`
- `実行契約`
  - 対象repo
  - 最初に読む順番
  - 依存成果
  - 変更可能範囲
  - 変更禁止範囲
  - 維持する契約
  - 検証
  - 停止・エスカレーション条件
  - 完了時に返す情報
- `実装結果`は実装後にplanctlが追加
- `終了記録`はarchive時に追加

### program.md に追加

- 非対象
- 正本境界
- 全体像・実行Wave
- 人間ゲート
- 子マップの `役割`、`対象repo`、`参照`
- 終了記録

モデル、worktree、branch、session IDはテンプレートに入れないでください。

### 新規テンプレート

```text
templates/実行指示.md
templates/実行結果.json
templates/終了記録.md
```

JSONテンプレートは有効なJSONにしてください。

---

## 8. plan lint

新規または既存拡張で、単発planと子計画の静的lintを作ってください。

必須確認:

- 必須セクション
- placeholder残存
- 子計画の親backlink
- 実行契約の必須項目
- 完了条件が1件以上
- 変更可能/禁止範囲が空でない、または理由が明記
- 対象repoがある、または `repo無し`
- Programマップの必須行
- `並列` / `レビュー` / `次` / `場所` / `依存`
- Programマップと子frontmatterの矛盾

既存 `program-lint` は互換維持してください。

---

## 9. archiveの再定義

バケット意味を次に揃えてください。

```text
planning = 未着手・検討中
active   = 実装・修正・AIレビュー中
paused   = 再開条件あり
done     = 最終評価全PASS・人間のクローズ判断待ち
archive  = 人間確認済みの閉じた計画
```

終了区分:

```text
completed
superseded
merged
conflict
cancelled
```

終了記録必須項目:

- 終了区分
- 終了日時
- 人間確認
- 理由
- 後継・統合先
- 実装済み範囲
- 未完了事項
- レビュー・判断根拠
- 関連commit/評価

`completed`だけ、全完了条件・最終評価PASS・Program全子完了を要求してください。

`superseded/merged/conflict/cancelled`は未完了を許しますが、理由、人間確認、未完了事項を必須にしてください。`superseded/merged/conflict`は後継・統合先を必須にしてください。

未完了計画をcompletedに偽装しないでください。

---

## 10. bucketctl拡張

既存互換を維持し、次の許可遷移を実装してください。

```text
planning → active
active   → paused / done
paused   → planning / active
done     → active / archive
planning/active/paused → archive
  ※ 非completed終了だけ
```

必須:

- 既定dry-run
- `--apply`
- `--commit`
- 対象path限定
- `--force`なし
- 自動追い出しなし
- 人間確認記録なしのarchive拒否
- final評価なしのcompleted拒否
- `check --json`
- active=3、paused=3、done=8、planning/archive=無制限
- 超過済みバケットから外へ出すのは許可
- 移動先上限を超える流入は拒否
- 件数、上限、対象一覧、必要な人間判断を表示

---

## 11. planctl追加

追加先:

```text
personal-os/AIエージェント基盤/skills/plan-ops/scripts/planctl.py
```

サブコマンド:

### `prepare`

- plan/program/childを明示引数で受ける
- task_id、runtime、repo、base SHA、worktree、branchをrun manifestへ書く
- 実行指示を生成
- stateはgitignore配下

### `progress`

- Programの既存子ブロックを更新
- state / next / ref
- 対象子以外をバイト不変

### `apply-evaluation`

- 対象計画と評価MDを明示引数で受ける
- 完了条件の文言と評価項目を完全一致
- PASSだけ `[x]`
- FAIL/対象外/不明が1つでもあれば完了にしない
- 実装結果を追記
- Program子の状態とチェックボックスを同期
- result commitを参照へ記録
- lintを実行
- manifest phaseを `synced` にする

### `close`

- 終了区分と人間確認を記録
- 終了条件を検証
- bucketctlを通してarchiveへ移動
- Programの場合は親全体の整合を検査

### `sync-check`

- result packet
- 評価MD
- 完了条件
- 子状態
- Programマップ
- bucket
- 終了記録

の整合をJSONと人間向け出力で返す。

推測で対象planを探さず、常に明示pathを使ってください。

---

## 12. result packet

実装workerは次のJSONを必ず返します。

```json
{
  "version": 1,
  "task_id": "",
  "status": "done",
  "base_commit": "",
  "result_commit": "",
  "changed_paths": [],
  "tests": [
    {
      "command": "",
      "status": "passed",
      "summary": ""
    }
  ],
  "assumptions": [],
  "blockers": [],
  "remaining_risks": [],
  "out_of_scope_findings": []
}
```

`status`は `done|blocked|partial|failed`。

未実行テストをpassedにしないでください。

---

## 13. runtime-neutral harness

追加先:

```text
personal-os/AIエージェント基盤/agents-registry/harness/
```

構成:

```text
harness/
├── delegate.py
├── manifest.py
├── worktree.py
├── runtimes/
│   ├── codex.py
│   └── claude.py
├── schemas/
│   ├── run-manifest.schema.json
│   └── result-packet.schema.json
└── tests/
```

必須機能:

- runtime=`codex|claude`
- role=`explorer|implementer|reviewer`
- plan path必須
- write taskは明示base SHA
- 並列write/dirty checkout/別repo handoffはtask-scoped worktree
- read-only taskはworktree省略可
- worktreeとbranchはTask IDで命名
- agent定義からworktreeを決めない
- nearest AGENTSを読むよう指示
- plan、親Program、referencesの読む順番を指示
- 完了時にresult packet
- process outputをstateへ保存
- secret非表示
- push/mergeなし
- conflict時は停止
- worktree削除は人間ゲートまたは明示cleanup

### Codex adapter

既存 `/codex-impl` の `codex exec --json` とresume知見を再利用してください。

### Claude adapter

実装時点のローカル `claude --help` と公式non-interactive仕様を確認してください。使用可能なフラグをテストで固定し、未対応なら明示的にfeature-disabledで返してください。

---

## 14. カスタムエージェント

追加先:

```text
agents-registry/roles/
agents-registry/claude/agents/
agents-registry/codex/agents/
```

役割は3つだけから始めてください。

### explorer

- read-only
- 実行経路・所有・依存を調べる
- 編集しない
- 推測ではなくpathとsymbolを返す

### implementer

- workspace-write
- 一つのTask Packetだけ実装
- 最小で安全な変更
- 範囲外作業を始めない
- result packet必須

### reviewer

- read-only
- 完了条件とdiffを照合
- 自己申告を根拠にしない
- PASS/FAIL/対象外と根拠
- 編集しない

エージェント定義には次を入れないでください。

- 固定worktree
- 固定branch
- Program固有背景
- 長い性格
- 固定の実行Task
- runtimeをまたぐ詳細手順
- 毎回変わるモデル

性格は各1行まで。

Codexの内部referenceとchecklistにある「`.codex/agents/*.toml`は存在しない」という旧記述を、現行仕様とローカルversion確認を両立する書き方へ更新してください。

---

## 15. `/codex-impl`互換

既存:

```text
agents-registry/claude/commands/codex-impl.md
```

は削除しないでください。

新しい共通delegateを呼ぶ互換ラッパーにします。

- plan path
- runtime=codex
- role=implementer
- base SHA
- worktree policy
- result packet
- impl-reviewer
- planctl apply-evaluation

を使うようにします。

汎用コマンド名は `delegate-impl` 等でよいですが、命名を増やしすぎないでください。

---

## 16. Hook

session-boardへ計画編集責務を追加しないでください。

新規:

```text
hooks-registry/hooks/plan-closeout/
```

runtime別薄いシム:

```text
hooks-registry/claude/session-end/plan-closeout-session-end.py
hooks-registry/codex/session-end/plan-closeout-session-end.py
```

必要ならSubagentStopシムも追加します。

### Stop判定

`PLAN_RUN_MANIFEST`が無ければ通す。

manifestがある場合:

```text
running / implemented:
  通す

review_passed かつ syncedでない:
  継続させる
  planctl apply-evaluation / sync-checkを要求

synced / closed:
  通す

blocked:
  通すが、blockerを結果に残す
```

Hookはplanを編集しません。

### SubagentStop

- implementerでresult packetなし → 継続
- reviewerで必須評価項目なし → 継続
- explorerは構造化結果があれば通す

### 注意

- 無限ループ防止
- `stop_hook_active`を考慮
- 連続block上限
- stdout JSON契約をruntime別にテスト
- 既存session-board Stopと共存
- Hook失敗で既存作業を破壊しない

Hook本体・fixture・E2Eを先に実装してください。

Claude settings、Codex hooks.json、symlink、Codex `/hooks`再trustは、人間に差分を示して承認を得るまで適用しないでください。

---

## 17. session-board更新

session-boardの所有境界を維持します。

更新内容:

- 計画の実行・完了同期はplan-ops/plan-closeoutが所有
- session-boardはplan short refと実行ログだけを持つ
- `session-end.md`は、planありの完了前に `planctl sync-check` を案内
- `finish`はarchive承認ではない
- `common.py`の初回ガイド・ミラーを新規律へ短く更新
- Program/Plan判定は新しい正本へのポインタにする
- 詳細本文をcommon.pyへ重複コピーしすぎない
- Claude milestoneは最終評価とplan syncの不足を検知する
- CodexのStop Hook現行仕様を内部ドキュメントへ反映

---

## 18. plan-triage更新

Orcaの2/3ペインを既定出力から外してください。

新しい出力:

```text
規模:
形態: quick / plan / program
対象repo:
計画置き場:
実行形: direct / delegated-single / delegated-parallel / integration
必要役割:
write lane数:
worktree: 不要 / task-scoped
レビュー: 自己 / 1pass / full
人間ゲート:
判定理由:
```

Orcaは任意adapterとして関連節へ移してください。

モデル選択は `AIモデル一覧.md` を参照し、plan本文に固定しないでください。

---

## 19. handoff-plan-supervisor更新

独自の別テンプレートを持たず、`plan-ops/templates/実行指示.md`を正本として参照してください。

必須情報:

- 目的
- 非対象
- 読む順番
- 対象repo
- base
- 変更可能/禁止path
- 依存成果
- 実装内容
- 検証
- 停止条件
- result packet
- worktreeはハーネス割当済みであること

長い背景はplan/referencesに逃がしてください。

---

## 20. Area pilot

まず `areas/ai運用` だけで実施してください。

- identity内容をAGENTSへ統合
- identity削除は人間確認後
- `知識/`の各ファイルを読み、次へ分類
  - 特定計画references
  - Program共有references
  - AGENTSへ統合すべき短い判断基準
  - 本当に横断的で残すべき資料
- 一括移動・一括削除しない
- 移動候補一覧を先に提示
- 人間承認後に対象限定で移動
- work/money/healthはpilot合格後

---

## 21. テスト

最低限、次を追加してください。

### Plan lint

- 正常plan
- 必須節欠落
- placeholder残存
- 実行契約欠落
- 子backlink不正
- Programマップ必須行欠落

### Evaluation sync

- 全PASSでcheck更新
- FAILで拒否
- 対象外で拒否
- 文言不一致で拒否
- 間違った子番号で拒否
- result commit欠落で拒否
- Program map同期

### Archive

- completed成功
- completedだが評価なしで拒否
- conflict成功
- conflictだが理由なしで拒否
- mergedだが後継なしで拒否
- 人間確認なしで拒否
- 未完了をcompletedにしない

### Harness

- 明示baseからworktree
- task名でbranch/worktree
- dirty checkout分離
- read-onlyはworktree省略
- result JSON validation
- parallel taskの分離
- conflict停止
- secret非表示

### Hooks

- manifestなし
- running
- review_passed未同期
- synced
- implementer result欠落
- reviewer評価欠落
- stop_hook_active
- Claude/Codex stdout契約

### E2E

1. 単発plan → Codex実装 → Claudeレビュー → plan同期 → done
2. Programの独立2子 → 2worktree → 統合 → Program同期
3. 並行計画との矛盾 → conflict終了記録 → archive
4. completed → final PASS → 人間確認 → archive
5. session finishだけではarchiveされない

全テストは合成データを使い、実Turso、実secret、実Dailyを触らないでください。

---

## 22. 実装順

1. 親Programの子計画再編
2. テンプレートとlint
3. planctlとarchive
4. harnessとresult packet
5. agent定義
6. `/codex-impl`互換化
7. Hook本体とテスト
8. session-boardポインタ更新
9. ai運用pilot
10. E2E
11. 人間へHook登録・rename・移動の承認セット提示
12. 承認後だけruntime適用

各Waveを別commitにしてください。`git add -A`は禁止です。

---

## 23. 停止条件

次に当たったら実装を止め、根拠を添えて報告してください。

- 既存未コミット変更と対象pathが衝突
- 現在のClaude CLIで安全なnon-interactive呼び出しを確認できない
- Codex/Claude Hookの現行wire formatがローカルversionと公式説明で一致しない
- `identity.md`または`知識/`に別のconsumerがあり、移動で壊れる
- 既存計画をrename/move/archiveする必要がある
- runtime設定、symlink、trust変更が必要
- main merge、push、本番操作が必要
- secretまたはcredentialを発見
- Programの正本が複数競合している
- planctlが明示pathなしに対象を推測しないと実装できない

---

## 24. 完了報告

次の形式で返してください。

```markdown
## 実装結果

- 状態: done / partial / blocked
- base commit:
- 最終commit:
- Wave別commit:
- 変更ファイル:
- 新規ファイル:
- 削除候補（未実行）:
- 移動・改名候補（未実行）:
- テスト:
- E2E:
- Hook登録状況: 未適用 / 適用済み
- Codex trust状況:
- Claude adapter状況:
- 既存互換性:
- 未解決リスク:
- 人間判断が必要な項目:
- 次の一手:
```

push、main反映、runtime登録、計画移動は、明示承認なしに実行しないでください。
