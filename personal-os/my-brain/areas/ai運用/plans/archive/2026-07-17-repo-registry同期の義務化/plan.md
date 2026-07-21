分類: 横断 ／ 種別: 既存改善
大幅更新日: 2026-07-17
規模: ライト
形態判定: 単発 ／ 理由: 変更対象がrepo-registryと関連skill手順に閉じ、1コミット単位でrollbackできるため
並列: 不可 ／ レビュー: 都度

# repo-registry同期の義務化

## 目的

repoの作成・移動・退避が `repo-registry/repo概要.md` と `logs/` に確実に反映される状態を作る。読む側4系統（plan-triage・session-board hook・loop-creator・morning-routine）が依存する一覧に「書く責務」を明文化し、ズレを機械検知できるようにする。

## 非対象

- repoの物理移動・削除・archiveの実行（skill手順の文言整備のみ）
- hookの新設・launchd登録（機械検知はon-demandのcheck scriptで行い、イベント発火は使わない）
- Global Skill registry・plan-registryの構造変更
- repo概要.mdへの現在状態の詳細複製（ポインタ原則は維持する）

## 現状

2026-07-17の同期評価（本セッション・Artifactレポート）で確認したズレ:

1. `repo概要.md` は読む側が4系統あるのに、repo-create / repo-relocation のどのworkflowも更新を指示していない（書く責務ゼロ）。
2. `repo-registry/AGENTS.md` §1の役割宣言に `repo概要.md` 自体が載っていない。
3. repo-createの指示は「logs/ の更新**要否を確認**」止まりで、更新実行を義務化していない。
4. logsは2026-06-28の一括登録が最後。「仕事」repoはregisteredログ自体が無い。07-05のai-agent-foundation統合、07-10のpaused外付けSSD退避（`/Volumes/PortableSSD/mac-offload/2026-07-10-projects-paused`）がmovedログ未記録。
5. `repo-registry/AGENTS.md` の「現在状態は projects/{active,paused,archive} の実体配置を正とする」が、paused外付け退避の現実を説明できていない。

## 実行契約

- 対象repo: `/Users/kitamuranaohiro/Private`（personal-os/AIエージェント基盤 配下中心）
- 実行形: direct
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/AGENTS.md` と `repo-registry/AGENTS.md`・`repo-registry/logs/AGENTS.md`
  2. この計画
  3. `skills/repo-create/`・`skills/repo-relocation/` の対象workflow
- 依存成果: なし（2026-07-17同期評価の所見はこの計画の「現状」に転記済み）
- 変更可能範囲: `personal-os/AIエージェント基盤/repo-registry/`（AGENTS.md・repo概要.md・logs/追記）、`personal-os/AIエージェント基盤/skills/repo-create/`、`personal-os/AIエージェント基盤/skills/repo-relocation/workflows/move-repo.md`、`personal-os/AIエージェント基盤/skills/morning-routine/SKILL.md` の突き合わせ手順1行
- 変更禁止範囲: `projects/` 実体、`hooks-registry/`、他Global Skill本文、既存logsファイルの書換（追記・新規のみ）
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: repo概要.mdはポインタのみ（現在状態の詳細を複製しない・migration-contract.md §の既存原則）／logsは追記のみ／CLAUDE.md→AGENTS.md symlink維持
- 検証: `plan-lint.sh` PASS、新設check scriptを `bash -n` と実行で確認（追い付き後に全緑）、変更ファイルへのsecret混入なし
- 停止・エスカレーション条件: repo概要.mdの定型化が既存参照（repo-create/references/migration-contract.md 等）と矛盾する場合、または「実体配置を正とする」文言の書換が二重管理を生むと判明した場合は人間確認
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

hookは使わない（「repo作成」を確実に捉える単一イベントが無く、毎セッション検査は過剰。hook追加自体が人間ゲート対象）。plan-opsの `bucketctl check` と同じ「書く責務はskill手順・検知はon-demand script」の二段構えにする。

1. **書く責務の義務化**: `repo-create/workflows/create-repo.md` 手順8を「管理対象repoならregisteredログを**作成し**、repo概要.mdへ**追記する**（同一作業単位）」へ改め、SKILL.md役割・出力節も追従。`repo-relocation/workflows/move-repo.md` にもrepo概要.mdの場所行更新を1手順追加して対称にする。
2. **責務の正本宣言**: `repo-registry/AGENTS.md` §1へ「repo概要.md: 担当repo判定の索引。repoの登録・移動・archiveと同一作業単位で更新する」を追記し、完了条件にも反映。paused外付け退避の扱い（実体配置の正の但し書き）を1行足す。
3. **機械検知**: `skills/repo-create/scripts/repoctl-check.sh`（新設）で ①`projects/{active,paused,archive}/` の実体repo ②repo概要.mdの掲載 ③registeredログの有無 を3点突合し、ドリフトを一覧表示する。repo-createの完了確認と、morning-routineの既存「突き合わせ」手順（SKILL.md手順3）から呼ぶ。置き場はrepo-create配下を第一候補とし、実装時にplan-ops方式と整合しなければ人間確認。
4. **一覧の定型化**: repo概要.mdの各repoを定型リスト4行（役割/場所/入口/登録ログ）へ統一する。人間は縦読み、scriptは `場所:` 行を突合に使う。表は使わない。
5. **現物の追い付き**: 「仕事」registeredログ新規作成、07-05統合・07-10 SSD退避のmovedログ追記（logs/AGENTS.md書式）、その後checkが全緑になることを確認。

## 完了条件（レビュー項目）

- [x] `skills/repo-create/workflows/create-repo.md`: 管理対象repo作成時にregisteredログ作成とrepo概要.md追記が「要否確認」でなく実行手順として書かれ、出力節にrepo概要.md更新有無の項目がある
- [x] `skills/repo-relocation/workflows/move-repo.md`: repo移動時にrepo概要.mdの `場所:` 行を同一作業単位で更新する手順がある
- [x] `repo-registry/AGENTS.md`: §1にrepo概要.mdの役割と更新責務（登録・移動・archiveと同一作業単位）が宣言され、paused外付け退避時の実体配置の但し書きがある
- [x] `skills/repo-create/scripts/repoctl-check.sh`: 実行すると実体repo・repo概要.md掲載・registeredログの3点突合結果を出力し、意図的に1件ズラすと検知される（bash -n も通る）
- [x] `repo-registry/repo概要.md`: 掲載全repoが定型リスト（役割/場所/入口/登録）で統一され、詳細な現在状態の複製が無い
- [x] `repo-registry/logs/repositories/`: 「仕事」のregisteredログ、07-05統合と07-10 SSD退避のmovedログが存在し、logs/AGENTS.mdの書式（日付時刻JST・月フォルダ配下のMM-DD-repo-id.md命名）に合致する
- [x] `skills/morning-routine/SKILL.md`: 手順3の突き合わせがrepoctl-check.shの実行を参照している
- [x] 追い付き完了後に repoctl-check.sh が全緑で終了する
- [x] 変更・新設ファイルにsecretが無く、`CLAUDE.md -> AGENTS.md` symlinkが全対象フォルダで維持されている

## 実装結果
- result: 284dbf1 ／ 評価: 評価01.md


実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

同フォルダ `終了記録.md` を正本とする（2026-07-21クローズ・completed）。
