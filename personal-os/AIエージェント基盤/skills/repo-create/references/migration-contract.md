# repo migration contract

`repo-create` が既存repoへAI運用標準を移植する時の、read-only監査とdry-run出力の契約。実装scriptはこの契約と `scripts/fixtures/migration-cases.json` を同時に満たす。

## 1. 適用範囲

対象commandは `audit-repo`、`inventory-legacy-plans`、`scaffold-repo`、`audit-all`。このreferenceは出力と判定を定義するだけで、既存ファイルの移動・削除・上書き、commit、push、hook/launchd登録を許可しない。

modeは次の3つだけにする。

1. `read-only`: 状態を読み、findingを返す。書き込み0件。
2. `dry-run`: apply候補をoperationとして返す。書き込み0件。
3. `apply`: 人間が許可したpathだけを作る。既存ファイルは上書きしない。

## 2. canonical identity

targetはrequested pathの見た目ではなく、次の順でidentityを解決する。

1. `repo-registry/repo概要.md` は担当repoへのポインタとしてだけ使い、領域表や現在状態を複製しない。
2. mounted repoは最寄りのrepo-local `AGENTS.md` と、そのrepo自身のGit common dirでcanonical identityを決める。
3. linked worktreeはGit common dirが同じcanonical repoへdedupeする。branchやworktree pathを別repoとして数えない。
4. target自身に`.git`がなく、直下に複数のlinked worktreeがあるdirectoryは `worktree-container` とする。親directoryのGit repoを継承しない。
5. registryまたは配置履歴にあるが実体がmountされていないrepoは `deferred-unmounted` とし、存在する扱いで監査しない。

identity enumは `repo`、`linked-worktree`、`worktree-container`、`non-repo`。mount state enumは `mounted`、`deferred-unmounted`、`missing`。

dedupe keyは値を含まない安定識別子にする。優先順は `registry:<repo-id>`、`git-common-dir:<normalized-id>`、`path:<normalized-path>`。remote URLやcredentialをdedupe keyへ入れない。

## 3. 計画箱のfail-closed解決

work planは必ず次の順で解決する。

1. repo-registryから担当repoだけを決める。
2. canonical repoの最寄り `AGENTS.md` から宣言済み計画箱と分類契約を読む。
3. 宣言された検索範囲で既存planを先に探し、合流候補を返す。
4. 既存planが無い時だけ、宣言済み計画箱を新規作成先候補にする。

計画箱が未宣言なら `PLAN_BOX_MISSING`、複数候補が同順位なら `PLAN_BOX_AMBIGUOUS` を返してexit 3とする。root `plans/` を自動作成しない。既存planの移動・改名・廃止はinventoryへ分類するだけで、自動提案operationにしない。

plan classification enumは次だけに固定する。

- `current-execution`
- `product-plan`
- `spec`
- `history`
- `reference`
- `asset`
- `unknown`

`unknown` が1件でもあれば移動せず、人間判断を要求する。

## 4. 決定的JSON envelope

全commandは同じtop-level keyを同じ順序で返す。該当しない値は削除せず `null`、`[]`、`0` を使う。

```json
{
  "schema_version": "repo-create.migration.v1",
  "command": "audit-repo",
  "mode": "read-only",
  "target": {
    "requested_path": "$REPO",
    "canonical_path": "$REPO",
    "registry_id": null,
    "lifecycle": "active",
    "mount_state": "mounted",
    "identity": "repo",
    "dedupe_key": "path:$REPO",
    "repo_type": "unknown"
  },
  "git": {
    "head_sha": null,
    "branch": null,
    "upstream_name": null,
    "dirty_count": 0,
    "worktree_count": 0
  },
  "governance": {
    "agents_path": null,
    "agents_hash": null,
    "claude_kind": "missing",
    "claude_target": null,
    "plan_box_status": "missing",
    "declared_plan_box": null,
    "candidate_plan_boxes": []
  },
  "work_plan": {
    "search_roots": [],
    "existing_plan_candidates": [],
    "new_plan_destination": null,
    "classifications": []
  },
  "repo_audit": {
    "handoff_contract": "missing",
    "hook_findings": 0,
    "cross_repo_symlinks": 0,
    "program_lint_targets": []
  },
  "operations": [],
  "findings": [],
  "summary": {
    "pass": false,
    "warning_count": 0,
    "error_count": 0,
    "human_gate_count": 1
  },
  "redaction": {
    "secret_references_detected": 0,
    "secret_values_emitted": 0
  }
}
```

## 5. 決定性

1. key順は上のenvelopeに固定する。
2. path配列、finding、operation、classificationは `path`、`code`、`id` の順で辞書順sortする。
3. timestamp、実行時間、inode、端末固有temp pathを比較対象JSONへ入れない。
4. fixture pathは `$FIXTURE_ROOT`、対象repoは `$REPO`、Private rootは `$PRIVATE` に正規化する。
5. hashは内容hashだけを許可し、secretを含むファイルはhashも出力しない。
6. human-readable文言ではなく、安定したfinding codeとenumをテストする。

## 6. exit code

優先順位は `4 > 3 > 2 > 0`。

| code | 意味 |
|---|---|
| `0` | 契約PASS、またはaudit-all内で安全にdedupe/skipできた |
| `2` | 自動実行を止める修正必要finding、またはdry-runに変更候補がある |
| `3` | 計画箱、正本、mount、移動など人間決定が必要 |
| `4` | invalid input、壊れたGit metadata、runtime error |

`audit-all` はactive repoの最大exit codeを返す。`deferred-unmounted` は一覧へ残すが、active repoのPASSを偽FAILにしない。

## 7. secret境界

1. `.env`、credential、token、hook設定を読む必要があっても、値をparse結果、標準出力、stderr、log、fixture、評価mdへ出さない。
2. 出力可能なのはfinding code、件数、正規化path、rule idだけ。
3. `secret_values_emitted` は常に `0`。0以外はexit 4とし、出力自体を破棄する。
4. fixtureは `synthetic_secret_present: true` のような存在フラグだけを使い、秘密らしい文字列を持たない。

## 8. fixture

正本fixtureは `../scripts/fixtures/migration-cases.json`。fixtureは実repoのsnapshotコピーではなく、監査で確認した差分を値なしの合成inputへ落としたもの。各caseは最低限 `id`、`command`、`mode`、`input`、`expected` を持ち、expectedにはexit code、canonical identity、dedupe key、finding code、secret値出力件数を含める。
