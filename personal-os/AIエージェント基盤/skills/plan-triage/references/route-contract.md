# route contract

`plan-triage` の二段ルーティングとhandoff出力の唯一の契約。計画本文、plan header parser、状態索引は所有しない。

## 1. 解決順

1. repo内起点: canonical repo → 最寄りAGENTS → 宣言範囲の既存plan → 宣言箱。
2. Private/headless起点: repo-registryで担当repoだけ → canonical repo → 最寄りAGENTS → 宣言範囲の既存plan → 宣言箱 → 対象repo session handoff。
3. 既存planが1件なら必ず合流する。0件なら宣言箱を候補にする。複数なら人間判断まで停止する。
4. repo-registryは領域、project、plan path、状態を持たない。

## 2. 計画類型

- `area-local`: repo内の領域・project固有箱。
- `repo-root`: repo AGENTSが宣言したroot bucket箱。
- `repo-declared`: `docs/ai/plans/active` 等、repoが独自に宣言した箱。
- `global-area`: personal-os横断・Global Skill・loopのarea計画。
- `none`: サクッと、または停止中。

root `plans/` は類型ではなく、repo AGENTSが宣言した時だけ使える物理pathである。

## 3. JSON envelope

全keyを次の順序で返す。値が無いfieldも削らず `null`、`[]`、`false` を使う。

```json
{
  "schema_version": "plan-triage.route/v1",
  "origin": "private",
  "action": "create_new",
  "canonical_repo": "$REPO",
  "repo_rules": {"path": "$REPO/AGENTS.md", "content_hash": "synthetic"},
  "registry_reads": 1,
  "search_roots": [],
  "existing_plan_candidates": [],
  "canonical_plan_path": null,
  "plan_class": "none",
  "execution_cwd": "$REPO",
  "handoff_required": true,
  "handoff": {
    "canonical_repo_path": "$REPO",
    "plan_ref": null,
    "worktree_cwd": "$REPO",
    "allowed_paths": [],
    "forbidden_actions": [],
    "start_git_snapshot": null
  },
  "stop_reason": null,
  "findings": [],
  "exit_code": 0,
  "secret_values_emitted": 0
}
```

## 4. actionとexit

| action | exit | 意味 |
|---|---:|---|
| `no_plan` | 0 | サクッと。計画書なし |
| `join_existing` | 0 | 一意な既存planへ合流 |
| `create_new` | 0 | 一致0件・宣言箱一意。まだ書き込まない |
| `stop` | 3 | 人間判断が必要。全writer停止 |

invalid inputやruntime errorだけexit 4とする。routeは実装修正のexit 2を持たない。

## 5. finding code

- `REPO_NOT_REGISTERED`
- `AGENTS_MISSING`
- `PLAN_BOX_MISSING`
- `PLAN_BOX_AMBIGUOUS`
- `EXISTING_PLAN_AMBIGUOUS`
- `HANDOFF_INVALID`

未知codeをその場で増やさず、本contractとfixtureを同じ変更単位で更新する。

## 6. handoff

Private/headless起点で対象repoに書く場合、次の6 fieldを全て要求する。

1. `canonical_repo_path`
2. `plan_ref`
3. `worktree_cwd`
4. `allowed_paths`
5. `forbidden_actions`
6. `start_git_snapshot`

`worktree_cwd` がcanonical repoと異なるGit common-dirに属する、snapshot不一致、field欠損なら `HANDOFF_INVALID`。linked worktreeは、`git rev-parse --git-common-dir` でcanonical repoと同一だと確認できる場合に限り許可する。新しい可視sessionが対象repoをrootとして登録され、AGENTS読了が確認されるまでPrivate側は書き込まない。session ID移管・reparentは禁止。

## 7. 決定性とsecret境界

1. pathとfindingは辞書順。
2. pathは `$PRIVATE`、`$REPO`、`$WORKTREE` へ正規化する。
3. timestamp、inode、temp path、remote URLを出力しない。
4. credentialは存在・件数・findingだけを扱い、値を出さない。`secret_values_emitted` は常に0。
5. 同一fixture・snapshotのJSONはbyte-identicalにする。

## 8. Child 10との境界

このcontractは候補pathとroute結果だけを扱う。plan header 5形態、状態、安定ID、alias、source link、重複IDの解析は所有repoの `work-plan-index/v1` に委譲する。route側に同等parserを作らない。
