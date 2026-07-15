分類: 横断 ／ 種別: 統合整理 ／ 形態: program ／ 規模: フル

# 計画運用ハーネス検証

## 目的

計画が必要な仕事を、AIの記憶や長いhook文だけに任せず、次の一本道で扱えるようにする。

```text
依頼 → サクッと判定 → 計画の置き場を解決 → 起案・合流 → 実装・レビュー → 人間確認
             │                 │                    │
             └ サクッと        └ plan-triage        └ plan-management / plan-ops
```

人が意識する入口は `plan-management` に1つへ寄せる。一方で、置き場の判定、雛形生成・lint、runtime hook はそれぞれの責務を保ち、同じ規約を複数箇所へコピーしない。

### 人間確認方針

最終一括（危険操作は実行前に個別承認）。通常子は独立レビューと修正が全PASSなら `完了（AIレビュー済み・全体人間確認待ち）` として閉じる。全子の完了条件と統合評価が全PASSになった時だけ、親programを人間確認へ上げる。runtime露出、hook登録、push、移動・削除などの危険操作は、この最終確認へ先送りせず該当子で実行前に止める。

## 全体像

### 採用する責務分担

1. `plan-registry/` を計画運用の正本入口にする。ここは規模・段階・レビュー・人間ゲート・責務地図を持ち、個々の計画本文や実行状態は所有しない。
2. `plan-management` は人間・AIが使う入口Skillにする。短い `SKILL.md` が、置き場・起案、program管理、レビュー/遷移のworkflowへ振り分ける。
3. `plan-triage` は書き込まない経路解決器、`plan-ops` は決定的なscriptを持つ手続きSkillとして残す。新Skillはこの2つを吸収しない。
4. UserPromptSubmitは「サクッとでなければ `plan-management` を使う」と短く知らせるだけにする。repo・計画箱・レビュー合否をhookが決定しない。

### 一時WIP例外（2026-07-14 人間承認）

`ai運用/plans/active/` は原則3件だが、本programをactiveへ昇格する時から、本programがactiveを離れるまでだけ4件を許可する。例外はこのarea・このprogramに限定し、既存計画の自動退避、5件目の昇格、他areaへの波及を許さない。`bucketctl` がこの終了条件を機械的に確認する。

### このprogramが扱う範囲

- Globalの計画運用ルールを `plan-registry/` に集約し、`GLOBAL_AGENTS.md`・areaの `AGENTS.md` は最小の入口・物理配置へ絞る。
- Global Skill `plan-management` を新設し、既存の `plan-triage` / `plan-ops` / `kickoff` との境界を明文化する。
- `plan-ops` の `SKILL.md` をrouterへ短縮し、既存scriptsを動かさずworkflow・参照へ整理する。
- hook再編が安定した後に、既存program「完了判定とアーカイブ運用」の子02がPrompt Submitの短い計画ゲートを実装できる契約を渡す。

### このprogramが今は扱わない範囲

- 既存の計画フォルダ・完了計画・archiveの移動や削除。候補を見つけても人間承認なしに動かさない。
- `hooks-registry/` の未コミット再編への直接編集。Prompt Submit本体は既存programの子02が所有する。
- runtimeへの新Skill symlink露出。正本・テスト・ログを整えた後、対象runtimeと差分を示して人間承認を得てから行う。
- plan本文やsession-boardに第2の状態台帳を新設すること。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [x] 01  計画運用の正本入口を集約 … 完了
    並列: 不可 ／ レビュー: 都度(正本地図・既存参照・移行漏れを照合)
    人間ゲート: なし
    次: 評価03の全PASSを人間が確認・承認済み（2026-07-14）。子02の実装へ引き継いだ
    場所: plans/01-計画運用の正本入口を集約.md ／ 依存: ―
- [x] 02  plan-management Skillを新設 … 完了
    並列: 不可 ／ レビュー: 都度(既存Skillとの責務・workflowの入出力・catalogを照合)
    人間ゲート: runtime露出は別の実行前承認
    次: 評価02の全PASSを人間が確認・承認済み（2026-07-15）。子04の接続契約へ進む
    場所: plans/02-plan-management-Skillを新設.md ／ 依存: 01
- [x] 03  plan-opsの入口を短縮 … 完了
    並列: 可 ／ レビュー: 都度(scriptの振る舞い不変・参照経路・全テストを照合)
    人間ゲート: なし
    次: 評価01の全PASSを人間が確認・承認済み（2026-07-14）。子02の実装と統合確認を待つ
    場所: plans/03-plan-opsの入口を短縮.md ／ 依存: 01
- [x] 04  Prompt Submitへの接続契約を引き継ぐ … 完了（AIレビュー済み・全体人間確認待ち）
    並列: 不可 ／ レビュー: 都度(既存program子02・hook再編・runtimeテスト境界を照合)
    人間ゲート: なし（本子は危険操作を実行しない。外部依存の既存program子02は実行前に個別承認）
    次: 評価02の全PASSを統合評価へ渡す。子04自身の人間確認は不要
    場所: plans/04-PromptSubmitへの接続契約を引き継ぐ.md ／ 依存: 01, 02 ／ 外部依存: 2026-07-15-計画立案実行完了基盤/plans/04（旧 2026-07-13-完了判定とアーカイブ運用/plans/02・2026-07-15改名）
- [ ] 05  子計画レビューと人間確認の粒度を修正 … 実装
    並列: 不可 ／ レビュー: 都度(正本・workflow・template・現在program・説明HTMLを照合)
    人間ゲート: なし
    次: 子の全PASSを親programの一括人間確認へ集約する規約と導線を実装し、独立レビューへ渡す
    場所: plans/05-子計画レビューと人間確認の粒度を修正.md ／ 依存: 01, 02, 03, 04

## 実行順

1. **計画レビュー**: このprogramと4子の対象・正本・人間ゲート・重複を静的に確認する。`program-lint` が通ることを起動条件にする。
2. **01を実装**: central contractを先に決める。ここで既存文章を丸ごと移植せず、どの文書が何を持つかを一意にする。
3. **02と03を実装・都度レビュー**: 02は人向け入口、03は機械手続きの入口整理であり、scriptsの責務は動かさない。03の文書分離は並行実装し、01の正本入口と接続することを独立レビューで確認する。
4. **04を引き継ぐ**: 既存hook再編のdirty範囲が安定してから、子02の計画と実装を更新する。hook登録やruntime露出は人間ゲート後だけ行う。
5. **統合評価**: catalog・logs・AGENTS/CLAUDE symlink・Skill HTML・静的テストを確認する。全PASS後に人間へruntime露出の可否を提示する。

## 完了条件（レビュー項目）

- [ ] `plan-registry/AGENTS.md` が、規模・レビュー・人間ゲート・各コンポーネントの責務を一意に案内し、計画本文・状態・履歴を二重所有していない。
- [ ] `GLOBAL_AGENTS.md` は全runtimeが必要とする最小のサクッと判定・人間ゲートだけを保持し、詳細な計画運用を `plan-registry/` へ案内する。
- [ ] `plan-management/SKILL.md` は70行以内で、既存planへの合流/新規起案、program管理、レビュー・遷移の3 workflowを直接選べる。`plan-triage` と `plan-ops` の本文をコピーしていない。
- [ ] `plan-triage` は経路解決のみ、`plan-ops` はscriptによる手続きのみ、session-boardは実行記録のみを担当し、hookがrepo・計画箱・レビュー合否を決めない。
- [ ] `plan-ops` の既存scriptsのpath・引数・テスト対象を変えずに、`SKILL.md` を70行以内のrouterへ整理できる。
- [ ] Prompt Submitへ渡す文言は「サクッと3条件が全YESでない、または不明なら `plan-management`」という最小契約に留め、実装は既存program子02とhook再編の安定後に行う。
- [ ] 新Skillのcatalog・作成ログ・`SKILL.html`、新registryの `AGENTS.md`・`CLAUDE.md`・`AGENTS.html`、関連する計画HTMLが正本との対応を保つ。
- [ ] runtime symlink・hook登録・既存計画の移動は、人間の明示承認なしに実行していない。
- [ ] program子は全PASSと個別人間ゲートの解消後に閉じ、親programだけが統合評価後の最終一括人間確認を待つ。

## 関連

- 全runtimeの最小ルール: `../../../../AIエージェント基盤/GLOBAL_AGENTS.md` §6–7
- planの物理配置・テンプレ: `../../AGENTS.md` §3–5
- 経路解決: `../../../../AIエージェント基盤/skills/plan-triage/`
- 機械手続き: `../../../../AIエージェント基盤/skills/plan-ops/`
- Skill作成規約: `../../../../AIエージェント基盤/skills/skill-creator-custom/`
- hook接続の既存計画: `../../planning/2026-07-15-計画立案実行完了基盤/plans/04-PromptSubmitとhookガード.md`（旧 `2026-07-13-完了判定とアーカイブ運用/plans/02`）
