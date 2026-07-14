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

- [ ] 01  計画運用の正本入口を集約 … 計画
    並列: 不可 ／ レビュー: 都度(正本地図・既存参照・移行漏れを照合)
    次: `plan-registry/` の契約、GLOBAL/areaの最小ポインタ、AGENTS/CLAUDE/HTMLを設計して実装する
    場所: plans/01 ／ 依存: ―
- [ ] 02  plan-management Skillを新設 … 計画
    並列: 不可 ／ レビュー: 都度(既存Skillとの責務・workflowの入出力・catalogを照合)
    次: 01の契約を読み、短いrouterと3 workflowを持つGlobal Skillを正本・ログ・catalog・HTMLまで作成する
    場所: plans/02 ／ 依存: 01
- [ ] 03  plan-opsの入口を短縮 … 計画
    並列: 可 ／ レビュー: 都度(scriptの振る舞い不変・参照経路・全テストを照合)
    次: 01の契約へポインタを揃え、SKILL.mdを70行以内のrouterへ分離し、既存scriptの置き場を可視化する
    場所: plans/03 ／ 依存: 01
- [ ] 04  Prompt Submitへの接続契約を引き継ぐ … 計画
    並列: 不可 ／ レビュー: 都度(既存program子02・hook再編・runtimeテスト境界を照合)
    次: 01/02の確定後、既存program「完了判定とアーカイブ運用」子02へ短い計画ゲート契約と依存を記録し、hook再編が安定したsessionで実装・E2Eへ渡す
    場所: plans/04 ／ 依存: 01, 02 ／ 外部依存: 2026-07-13-完了判定とアーカイブ運用/plans/02

## 実行順

1. **計画レビュー**: このprogramと4子の対象・正本・人間ゲート・重複を静的に確認する。`program-lint` が通ることを起動条件にする。
2. **01を実装**: central contractを先に決める。ここで既存文章を丸ごと移植せず、どの文書が何を持つかを一意にする。
3. **02と03を実装・都度レビュー**: 02は人向け入口、03は機械手続きの入口整理であり、scriptsの責務は動かさない。
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

## 関連

- 全runtimeの最小ルール: `../../../../AIエージェント基盤/GLOBAL_AGENTS.md` §6–7
- planの物理配置・テンプレ: `../../AGENTS.md` §3–5
- 経路解決: `../../../../AIエージェント基盤/skills/plan-triage/`
- 機械手続き: `../../../../AIエージェント基盤/skills/plan-ops/`
- Skill作成規約: `../../../../AIエージェント基盤/skills/skill-creator-custom/`
- hook接続の既存計画: `../../planning/2026-07-13-完了判定とアーカイブ運用/plans/02-PromptSubmit計画注入の再設計.md`
