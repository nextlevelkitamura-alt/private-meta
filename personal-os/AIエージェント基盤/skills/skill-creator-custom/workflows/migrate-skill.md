# migrate-skill

Skill移行、改名、runtime露出を行う時の最小ワークフロー。

## 手順

### Step 1: 対象と危険操作を確認する

1. 対象Skill名、旧正本、新正本候補を確認する。
2. Global Skillかrepo-local Skillかを確認する。
3. `meta` / `applied` のどちらに分類するか確認する。
4. 削除、移動、改名、symlink張り替えを含むか確認する。
5. 危険操作を含む場合は、人間の明示依頼または承認があるか確認する。
6. 削除が主目的なら `skill-delete` に委譲する。

### Step 2: 正本ルールを読む

1. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`
2. Global Skillなら `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md`
3. Global logs/catalogなら `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/logs/AGENTS.md` と `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/catalog/AGENTS.md`
4. repo-local Skillなら `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/AGENTS.md` と `repo-registry/logs/AGENTS.md`

確認すること:

1. 正本path
2. runtime露出先
3. direct symlink要否
4. logs更新先
5. Global catalog更新先、または所有repo側導線更新先
6. repo-localとして残すべき理由
7. `AGENTS.md` を移行または同梱する場合、同階層の `CLAUDE.md -> AGENTS.md` が必要か。

### Step 3: 旧実体を確認する

1. `readlink` でruntime露出の現在値を見る。
2. 旧実体が複数ある場合は、必要なdiff確認を行う。
3. symlink chainがある場合は、最終的な実体を確認する。
4. plugin/system/cache配下からの移行は、明示依頼がある場合だけ進める。
5. 採用する旧実体と理由を決める。

### Step 4: 正本へ移す

1. Global Skillは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/<skill>/` を新正本にする。
2. repo-local Skillは所有repo内を正本にし、無理にGlobal化しない。
3. `SKILL.md` は入口に保ち、長い運用ルールを重複コピーしない。
4. 一回限りの検証scriptや仮ファイルをrepoに残さない。
5. `AGENTS.md` を移行または同梱した場合は、同階層に `CLAUDE.md` がなければ `AGENTS.md` への相対symlinkを作る。
6. 既存の `CLAUDE.md` が非symlinkまたは別内容の場合は上書きせず、方針を確認する。

### Step 5: runtime露出を整える

1. Global Skillは `global-skill-registry/scripts/link-global-skill.sh --dry-run <skill>` で予定を確認する。
2. symlink作成・張り替えの承認がある場合だけ `global-skill-registry/scripts/link-global-skill.sh <skill>` を実行する。
3. 各runtimeから新正本へのdirect symlinkになっているか `readlink` で確認する。
4. runtime経由で `SKILL.md` を読めるか確認する。
5. 一部runtimeだけ露出する段階露出にする場合は、残りを作成/移行ログの `未露出バックログ:` 行へ列挙する（書式・追跡は `global-skill-registry/logs/AGENTS.md` §2/§6。`grep -r '未露出バックログ' global-skill-registry/logs/created/ global-skill-registry/logs/migrated/` で未完了露出を機械追跡）。承認で残りへ露出したら該当runtimeを `露出:` 側へ移す。
6. 既定露出は4窓（`~/.agents/skills`=Codex＋共通・`~/.claude/skills`・`~/.gemini/config/skills`・`~/.gemini/antigravity-cli/skills`）。`~/.codex/skills` は露出先にしない（Codexは `.agents/skills` を読む）。claude限定など恒久的に既定4窓と違う露出にするskillは `global-skill-registry/scripts/exposure-manifest.tsv` に例外登録し、`link-global-skill.sh` がそれに従う。
7. 露出後 `global-skill-registry/scripts/check-exposure.sh` でdrift（`~/.codex/skills` への二重登録・露出欠落・broken link）が無いか確認する。

### Step 6: 検証とログを書く

1. 可能なら `quick_validate` を実行する。
2. Global移行ログは `global-skill-registry/logs/migrated/YYYY-MM/MM-DD-<skill>.md`、repo-local移行ログは `repo-registry/logs/repo-local-skills/migrated/YYYY-MM/MM-DD-<repo-id>-<skill>.md` に書く。
3. `移行理由`、`正本選定`、`検証` を必ず入れる。
4. 改名時と削除時のログ統合は、Globalなら `global-skill-registry/logs/AGENTS.md`、repo-localなら `repo-registry/logs/AGENTS.md` に従う。
5. Global Skillは `global-skill-registry/catalog/AGENTS.md` に従い、該当catalogを更新する。
6. 移行後のcatalog行は、新しい正本pathを指すようにする。
7. repo-local Skillは所有repo側の現在導線更新要否を確認する。
8. scopeや分類が変わる場合は、旧catalogまたは所有repo側の導線から外し、新しい導線へ追加する。
9. 改名を伴う場合は、旧名の行を削除し、新名の行を追加する。
10. logs/catalog/所有repo側導線更新は別workflowに逃がさず、この移行workflowの完了条件として扱う。
11. 移行・改名でSkill本文が変わった場合は、完了条件として `<skill>/SKILL.html` を再生成する（`references/create-rules.md` §9）。改名時は旧 `SKILL.html` を残さない。

### Step 7: 報告する

1. 正本path
2. runtime露出の結果
3. logs更新先
4. Global catalog更新先、または所有repo側導線更新先。移動元があれば移動元
5. 検証結果
6. `AGENTS.md` を移行または同梱した場合は、`CLAUDE.md` symlink確認結果
7. 保留した差分や承認待ちがあればその内容
