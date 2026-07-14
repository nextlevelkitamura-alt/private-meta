---
name: loop-creator
description: repo固有またはglobalのloopを新規作成・変更し、所有repo、loop実体、registry、基盤directory symlink、launchd設定を整合させる。Use when「loopを作って」「朝に自動実行したい」「定期実行を追加」「このloopを変更して」。hook、手動コマンド、Codexのリマインダーやautomation、repo移動、Skill作成には使わない。
---

# loop-creator

定時・間隔で繰り返すloopを、所有repoの正本から安全に作成・変更するGlobal meta Skill。

## 1. 必ず読む

1. `workflows/create-or-update-loop.md`: 作成・変更、registry、directory symlink、launchd、人間ゲート、検証の全手順。
2. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/AGENTS.md`: loop境界と、その時点のregistry正本。
3. repo-localでは対象repoの最寄り `AGENTS.md` と宣言済み `loops/` rootの `AGENTS.md`。

## 2. 役割

1. 依頼がloopかを判定し、loopでなければ該当導線へ返す。
2. Globalかrepo-localかを決め、宣言済みのcanonical `loops/` rootだけを使う。
3. 新規は必須の `loop.md` だけをscaffoldし、script・logs・plistは必要時だけ追加する。
4. 基盤directory symlink、registry source reference、実装、launchd設定を照合する。
5. 作成・変更後に、正本、露出先、実行時状態、未実行事項を人間へ報告する。

## 3. 境界

1. repo選定と計画経路は `plan-triage`、repo root整備は `repo-create`、repo移動は `repo-relocation` に委譲する。
2. hookは `hooks-registry`、手動コマンドは所有Skillまたはrepoの `scripts/`、対話的なAI作業は可視ペインへ返す。
3. `implementation-links/` は人間用入口であり、実行path・削除基準・状態正本に使わない。

## 4. 安全方針

1. 未宣言root、正本不明、リンク不一致、registry競合では書き込まず停止する。
2. scaffoldは既定dry-run。既存loopや既存ファイルを上書きしない。
3. launchd登録解除・再登録・有効化・無効化・周期変更、symlink作成/置換、既存実装の移動・削除は実行直前に人間の明示承認を取る。
4. secret・token・credentialをplist、MD、HTML、ログ、Gitへ書かない。
5. mdとTursoを同時にregistry正本にしない。作業時点の `loops-registry/AGENTS.md` に従う。

## 5. 完了条件

1. `loop.md` と必要な実装・設定が一致し、未解決プレースホルダがない。
2. optional構成、plist、symlink、registry、ignore、関連テストを検証した。
3. 無承認のlaunchd変更、既存loop移動、外部書込みを行っていない。
