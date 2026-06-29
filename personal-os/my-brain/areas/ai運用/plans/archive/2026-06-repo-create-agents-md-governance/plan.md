分類: skill
種別: 統合整理

# repo-create / agents-md-governance 統合整理計画

## 種別

統合整理

## 変更内容

`agents-md-governance` の AGENTS.md 監査・再構成・Git棚卸し機能を `repo-create` 配下へ吸収し、`repo-create` をリポジトリライフサイクル入口にする。

## 目的

1. ユーザーが「repo」「リポジトリ」「AGENTS.md」「AgentMD」「GitHub接続」「repo登録」と言った時に、まず `repo-create` が入口になるようにする。
2. `agents-md-governance` という独立Skillを減らし、repo関係の導線を1つに寄せる。
3. `Skill削除`、`Skill改名`、`Skill移行` に `repo-create` が誤爆しないようにする。
4. AGENTS.md監査の4ブロック出力、repo種別判定、危険操作ゲートは維持する。

## 対象

1. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/repo-create/`
2. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/agents-md-governance/`
3. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/catalog/meta.md`
4. 必要に応じて `global-skill-registry/logs/`
5. 必要に応じて runtime symlink

## 選択肢

### A. 分離維持

`repo-create` は入口だけ広げ、AGENTS.md監査は `agents-md-governance` に委譲する。

判断:

1. 安全だが、Skillが2つ残り、ユーザー視点では分かりづらい。
2. 「repoのことはrepo-create」という目的に対して弱い。
3. 今後も `agents-md-governance` を覚える必要が残る。

結論: 採用しない。

### B. repo-createへ吸収し、agents-md-governanceをdeprecated化する

`agents-md-governance` のworkflow、reference、asset、scriptを `repo-create` へ移す。`agents-md-governance` は一時的に薄い委譲stubにする。

判断:

1. repo関係の入口が分かりやすい。
2. AGENTS.md監査ロジックを失わない。
3. いきなり削除しないため、runtimeやcatalogの破損リスクを抑えられる。
4. 検証後に `skill-delete` で削除できる。

結論: 推奨。

### C. repo-createをrepo-lifecycleへ改名してから吸収する

Skill名も責務に合わせて変える。

判断:

1. 名前は最も正確になる。
2. ただしruntime露出、catalog、ログ、参照更新の範囲が増える。
3. 今回は統合自体が主目的で、改名を同時にやるとリスクが増える。

結論: 今回は採用しない。統合後に必要なら別計画。

### D. 新しいrepo-governance Skillを作る

repo監査専用Skillを新設し、`repo-create` と `agents-md-governance` の間に置く。

判断:

1. Skill増殖になる。
2. 入口がさらに増える。
3. ユーザーの目的と逆方向。

結論: 採用しない。

## 推奨判断

選択肢Bを採用する。

`repo-create` をリポジトリライフサイクル入口にし、`agents-md-governance` の中身を `repo-create` 配下へ吸収する。`agents-md-governance` は即削除せず、deprecated stubにして検証期間を置く。

## repo-create の完成形

```text
repo-create/
  SKILL.md
  workflows/
    route-repo-request.md
    check-repo.md
    setup-repo.md
    audit-agents-md.md
    restructure-agents-md.md
    git-inventory.md
    closeout-git.md
  references/
    repo-routing.md
    repo-type-taxonomy.md
    agent-governance-rules.md
    folder-profiles.md
    git-policy-options.md
    repo-policy-storage.md
    git-safety.md
  assets/
    agents-report-template.md
    docs-git-policy-template.md
    agents-work-intake-template.md
    agents-git-policy-template.md
  scripts/
    repo_governance_audit.py
```

## workflow設計

### route-repo-request.md

目的: repo系依頼の最初の振り分け。

手順:

1. 依頼がrepo系か確認する。
2. `Skill削除`、`Skill改名`、`Skill移行`、`Global Skill registry` が主目的なら `skill-creator-custom` または `skill-delete` に逃がす。
3. `repo`、`リポジトリ`、`Repository`、`GitHub`、`remote`、`upstream`、`AGENTS.md`、`CLAUDE.md`、`AgentMD` が含まれる場合はrepo系として扱う。
4. 対象pathを決める。
5. `check-repo.md` に進む。
6. `check-repo.md` の結果で `setup-repo.md`、`audit-agents-md.md`、`restructure-agents-md.md`、`git-inventory.md`、`closeout-git.md` を選ぶ。

### check-repo.md

目的: 既存repoの状態確認と次workflow判定。

手順:

1. `git rev-parse --show-toplevel`
2. `git status -sb`
3. `git remote -v`
4. `git branch --show-current`
5. upstream確認
6. `AGENTS.md` / `CLAUDE.md` 有無確認
7. repo種別判定
8. repo registry logs更新要否確認
9. 4ブロックで結果を出す。

### audit-agents-md.md

目的: `AGENTS.md` / `CLAUDE.md` の監査。

移植元:

`skills/agents-md-governance/workflows/audit-agents-md.md`

変更点:

1. top-level Skill名を `repo-create` に合わせる。
2. `agents-md-governance` という表現を削る。
3. repo routing上の1 workflowとして、`check-repo.md` の結果を前提にする。

### restructure-agents-md.md

目的: AGENTS.md rewrite案、docs分割案、apply。

移植元:

`skills/agents-md-governance/workflows/restructure-agents-md.md`

変更点:

1. `apply` は人間承認必須。
2. 既存repo固有ルールを削らない。
3. `CLAUDE.md -> AGENTS.md` symlink確認を完了条件に残す。

### git-inventory.md

目的: worktree / branch棚卸し。

移植元:

`skills/agents-md-governance/workflows/git-inventory.md`

変更点:

1. repo初期設定やrepo監査から呼べる共通workflowにする。
2. cleanupは提案だけ。削除はしない。

## reference設計

### repo-routing.md

repo系依頼の振り分け表を置く。

拾う発話:

1. `リポジトリチェックして`
2. `このrepo GitHubにつないで`
3. `repo登録して`
4. `AGENTS.md見て`
5. `CLAUDE.md確認して`
6. `AgentMD整理して`
7. `remote/upstream確認して`

拾わない発話:

1. `Skill削除して`
2. `Skill改名して`
3. `Global Skillを移行して`
4. `runtime symlinkを張り替えて`
5. `catalogからSkillを消して`

近接Skill:

1. `skill-creator-custom`
2. `skill-delete`
3. `repo-relocation`
4. `coding-task-orchestrator`
5. `task-router`

### repo-type-taxonomy.md

移植元:

`skills/agents-md-governance/references/rule-taxonomy.md` のrepo種別部分。

役割:

1. `app`
2. `automation`
3. `docs`
4. `skill`
5. `personal-os`
6. `library/tool`
7. `unknown/mixed`

### agent-governance-rules.md

移植元:

`skills/agents-md-governance/references/rule-taxonomy.md` のAGENTS.md監査ルール部分。

役割:

1. 危険操作ゲート
2. AGENTS.md行数
3. docs分割
4. `CLAUDE.md -> AGENTS.md`
5. worktree / branch / PR / merge / push境界
6. deploy / DB / secret / migration境界

## asset/script設計

1. `assets/report-template.md` は `assets/agents-report-template.md` へ移す。
2. `scripts/agents_md_audit.py` は `scripts/repo_governance_audit.py` へ移す。
3. script内の表示名は `repo-create governance audit` または `repo governance audit` にする。
4. helper commandは `python3 ~/.agents/skills/repo-create/scripts/repo_governance_audit.py --repo /path/to/repo` に変える。

## agents-md-governance の扱い

### 移植直後

`agents-md-governance` は削除しない。`SKILL.md` だけを薄く残す。

役割:

1. deprecatedであることを書く。
2. `repo-create` を使うよう案内する。
3. 直接名指しされた時だけ、`repo-create` の該当workflowへ読み替える。

### 検証後

1. `repo-create` でAGENTS.md監査が問題なく動くことを確認する。
2. catalogで `agents-md-governance` をdeprecated扱いにする。
3. 参照検索で残参照を確認する。
4. 人間承認後、`skill-delete` で削除する。
5. 削除ログ、catalog更新、runtime露出削除を同じ作業単位で行う。

## description設計

### repo-create

入れる語:

1. `GitHub Repository作成`
2. `既存repo接続`
3. `リポジトリチェック`
4. `repo状態確認`
5. `remote/upstream確認`
6. `AGENTS.md初期設定`
7. `AGENTS.md監査`
8. `CLAUDE.md確認`
9. `repo registry登録`
10. `repo registryログ`

入れない語:

1. `登録`
2. `移動`
3. `削除`
4. `改名`
5. `初期設定`

上記の汎用動詞は、必ず `repo登録`、`リポジトリ移動`、`AGENTS.md初期設定` のように対象名とセットにする。

### agents-md-governance

移植後のdescription:

1. deprecatedであることを書く。
2. AGENTS.md監査は `repo-create` を使うと書く。
3. 新規発火を狙わない。

## 実行順

1. `repo-create/SKILL.md` のdescription、役割、対象外、読み込み方針、出力を更新する。
2. `repo-create/workflows/route-repo-request.md` を追加する。
3. `repo-create/workflows/check-repo.md` を追加する。
4. `repo-create/references/repo-routing.md` を追加する。
5. `repo-create/references/repo-type-taxonomy.md` を追加する。
6. `repo-create/references/agent-governance-rules.md` を追加する。
7. `agents-md-governance` のworkflowを `repo-create/workflows/` へ移植する。
8. `agents-md-governance/assets/report-template.md` を `repo-create/assets/agents-report-template.md` へ移植する。
9. `agents-md-governance/scripts/agents_md_audit.py` を `repo-create/scripts/repo_governance_audit.py` へ移植する。
10. `agents-md-governance/SKILL.md` をdeprecated stubへ縮小する。
11. `global-skill-registry/catalog/meta.md` を更新する。
12. `quick_validate.py` を `repo-create` と `agents-md-governance` に実行する。
13. repo系想定発話とSkill系想定発話で誤爆確認する。
14. 問題なければ次ターン以降で `agents-md-governance` 削除を `skill-delete` に委譲する。

## 完了条件

1. `repo-create` がrepo系入口として機能する。
2. `repo-create` からAGENTS.md監査、rewrite案、Git棚卸しが実行できる。
3. `Skill削除`、`Skill改名`、`Skill移行` で `repo-create` が誤爆しない。
4. `agents-md-governance` はdeprecated stubになっている。
5. `quick_validate.py` が成功する。
6. catalogの近接・注意が現在状態と一致する。
7. 削除、runtime露出削除、catalog削除はまだ実行しない。

## 関連するcatalog / logs / repo profile更新要否

1. `global-skill-registry/catalog/meta.md`: 更新必要。
2. `global-skill-registry/logs/`: 移植またはdeprecated化の履歴を短く残すか確認。
3. runtime露出: 移植段階では変更しない。削除段階で `skill-delete` に委譲。
4. repo profile: 対象外。

## 保留事項

1. `repo-create` という名前のまま進めるか、将来 `repo-lifecycle` に改名するか。
2. `agents-md-governance` のdeprecated期間をどのくらい置くか。
3. `repo-relocation` も将来 `repo-create` に吸収するか。
4. `task-router` のAGENTS整備導線を `repo-create` に寄せるか。

## 実装結果

1. `repo-create` に `route-repo-request.md`、`check-repo.md`、AGENTS監査workflow、git inventory、repo routing、repo type taxonomy、agent governance rules、4ブロックテンプレート、read-only helperを追加した。
2. `agents-md-governance` は削除せず、deprecated互換stubへ縮小した。
3. `global-skill-registry/catalog/meta.md` を現在状態に合わせて更新した。
4. `global-skill-registry/logs/migrated/2026-06/06-29-repo-create-agents-md-governance-integration.md` を追加した。
5. `quick_validate.py` は `repo-create` と `agents-md-governance` の両方で成功した。
6. `repo-create/scripts/repo_governance_audit.py --repo . --mode audit` は4ブロック出力を確認済み。監査上の `整える` 項目があるためexit codeは1。

## 削除追記

1. 2026-06-29に `skill-delete` で `agents-md-governance` を削除した。
2. 正本 `skills/agents-md-governance/` と5 runtime露出を削除した。
3. `global-skill-registry/catalog/meta.md` から削除し、削除履歴は `global-skill-registry/logs/deleted/2026-06/06-29-agents-md-governance.md` に集約した。
4. 新規のAGENTS/CLAUDE監査、AgentMD整理、repo governance確認は `repo-create` を使う。
