親計画: ../program.md ／ 分類: loop ／ 種別: 統合整理
並列: 可（基盤契約→repo root導入は順次） ／ レビュー: 都度

# 05 repo-local loop標準とLoop Creator

## 目的

仕事・Focusmapなど所有repoの自動実行を、各repoの `loops/<loop-id>/` に自己完結で置ける標準へ揃える。
基盤は `implementation-links/<repo-id> -> <repo>/loops/` の相対directory symlinkで発見可能にし、
実体の正本・実行経路・状態正本を混同しない。

## 現状

- global loopは `AIエージェント基盤/loops-registry/loops/` にあり、既存実装ごとに必要な構成で管理している。新規loopの定型は `loop.md` のみとし、plist・`scripts/`・gitignoreされた `logs/` は必要な時だけ追加する。既存のtests/state/outputは移動・削除しない。
- 仕事の既存loop実装は `scripts/` と `領域/整備/自動実行/` に分散する。2026-07-14に新規用 `仕事/loops/` rootと基盤のdirectory symlinkを導入したが、既存実装は移動していない。Focusmapには `scripts/focusmap-agent/` など複数の常駐導線があり、repo-local `loops/` rootはまだない。
- 基盤の `loops-registry/` はglobal実装だけを置く契約であり、repo-local実装のコピーを置く場所ではない。
- 現行7loopのTurso importは、既存実装を移動せずsource referenceを同期する方針で進行中である。

## 方針

1. `仕事/loops/` と `focusmap/loops/` を新設し、各rootに `AGENTS.md` と `CLAUDE.md -> AGENTS.md` を置く。各repoのroot `AGENTS.md` には、repo-local loopの正本が `loops/<loop-id>/` であり、新設・変更はGlobal Skill `loop-creator` を必須とする一行を追加する。
2. 新規loopの標準は必須の `loop.md` だけとする。必要な場合だけplist、`scripts/`、git非追跡の `logs/` を追加し、`tests/`・`state/`・`output/` は定型として作らない。lockは原則 `/tmp`、成果物は各repoの既存正本またはDBなど目的に合う場所へ置く。イベントhook、手動コマンド、一般的な常駐agentはloopと混同して置かない。
3. 基盤には `loops-registry/implementation-links/` を新設し、`仕事` と `focusmap` の**loops root全体**を相対directory symlinkで露出する。個別loopごとのリンクは作らない。新規loopはroot link経由で自動的に見える。
4. `loops-registry/AGENTS.md` と `implementation-links/AGENTS.md` は、正本・リンクの意味・削除安全規則・Tursoとの役割分担を人間に説明する。実装側のAGENTS本文を基盤へコピーしない。
5. Global Skill `loop-creator` はrepo-registryで対象repoを確定し、対象repoの `AGENTS.md` が宣言した `loops/` rootだけに作成する。作成時にTurso definitionのcanonical source path、root directory symlink、移行期間中の一覧参照を検証する。
6. 既存のglobal 4本・仕事3本・Focusmapの既存導線は、この子計画では移動しない。個々を `loops/<loop-id>/` へ移すのは、対象・launchd backup・rollbackを指定した別の人間承認済み移行作業にする。
7. launchdのenable/disable、周期変更、plist再登録、Notion廃止は本計画の対象外。plistを新規loopへ作る場合も、実機有効化は人間承認後だけにする。

## 進捗

- 2026-07-14: 仕事repoに `loops/AGENTS.md`、`CLAUDE.md -> AGENTS.md`、人間向け `AGENTS.html` を追加し、基盤の `implementation-links/仕事` をroot全体への相対directory symlinkとして作成した。既存実装とlaunchdは変更していない。
- 2026-07-14: Global Skill本体だけを所有する詳細計画を [planning/2026-07-14-loop-creator-Skill新規作成/plan.md](../../../planning/2026-07-14-loop-creator-Skill新規作成/plan.md) に分離した。本子計画はrepo展開とTurso移行との順序を引き続き所有する。
- 2026-07-14 17:02 JST: Global Skill `loop-creator` を基盤で正本化し、`SKILL.md`、作成/変更workflow、`loop.md`だけを作るdry-run scaffoldとtest、`SKILL.html`、catalog、created logを追加した。5 runtimeへ正本のdirect symlinkで露出し、launchdと既存loopは変更していない。
- 2026-07-14: 独立監査で検出したroot契約・同一apply・directory symlink検証・HTML図の不足を修正し、再監査PASSを確認した。以後のlaunchd変更には前後snapshot比較を必須化した。初回実装前のlaunchd snapshotは遡及できないが、この修正・再監査ではlaunchd変更をしていない。
- 2026-07-14: Focusmapに `loops/AGENTS.md`、`CLAUDE.md -> AGENTS.md`、白背景の `AGENTS.html` を追加し、root `AGENTS.md` に `loop-creator` 必須導線と既存 `scripts/` / `scripts/focusmap-agent/` / launchdを移動しない境界を追記した。基盤の `implementation-links/Focusmap` はcanonicalな `focusmap/loops/` への相対directory symlinkであり、`verify-repo-loop-link.sh` はPASS。Focusmap local `main` commit: `e3980f72`。既存実装・launchd・Turso・Notionには未変更。
- 2026-07-14 19:00 JST: 既存7loopを `launchctl print` と `plutil -lint` だけで確認し、6本loaded・1本（`daily-notion-sync`）は意図した安全停止中であることを記録した。baselineは [references/2026-07-14-既存7loop-readonly-baseline.md](../references/2026-07-14-既存7loop-readonly-baseline.md)。launchd・plist・script・Notion APIは変更していない。
- 次: **本子計画の標準導入は完了**。別計画として、既存7loopのsource reference整理とTurso移行の順序を確定する。既存実装の移設、launchd変更、Notion廃止は人間承認済みの移行作業としてのみ扱う。

## 完了条件（レビュー項目）

- [x] `仕事/loops/AGENTS.md` と `focusmap/loops/AGENTS.md` が、`loops/<loop-id>/` をrepo-local loopの唯一の実体置き場として宣言し、各 `CLAUDE.md` が本文コピーではなく `AGENTS.md` への相対symlinkである。
- [x] 両repoのroot `AGENTS.md` がGlobal Skill `loop-creator` の必須利用とloop rootを示し、既存の `scripts/`・`領域/`・`scripts/focusmap-agent/` を移動しないと明記する。
- [x] 基盤の `loops-registry/implementation-links/AGENTS.md` が、`<repo-id> -> <repo>/loops/` のdirectory symlink、正本ではないこと、リンク経由で削除しないことを説明する。
- [x] `implementation-links/仕事` と `implementation-links/focusmap` が相対symlinkであり、解決先が各repoのcanonical `loops/` rootと一致する。
- [x] `loops-registry/AGENTS.md` がglobal実装とrepo-local root linkの境界を示し、repo-local実装のコピーを置く誤解を生まない。
- [ ] `loop-creator` がrepo-registry→repo `AGENTS.md`→宣言済みloop root→Turso source reference→root directory symlinkの順に検証し、未宣言repoやリンク不一致をfail-closedにする。
- [ ] 既存7loopの実装path、launchd loaded状態、周期、Notion連携設定に変更がないことを、変更前後の対象diffとread-only確認で示せる。
