# My Brain Areas

このディレクトリは、work、ai運用、money、health などの継続領域を置く場所。
各areaは、考え、判断軸、計画を領域ごとに閉じて管理する。
personal-os の計画はここを単一正本にする。基盤・Skill・repo・loop計画は `ai運用/` が担当し、旧 `../../plans/` は廃止済み。

## 1. Area標準構成

新しいareaは、原則として次の形にする。

```text
areas/<area>/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  identity.md
  thinking/
  plans/
```

1. `AGENTS.md`: そのareaでAIが作業するための入口ルール。
2. `CLAUDE.md`: `AGENTS.md` への相対symlink。本文コピーは禁止。
3. `identity.md`: そのareaの目的、判断基準、置くもの、置かないもの。
4. `thinking/`: 考え、調査、仮説、方向性。
5. `plans/`: 実行する計画。

## 2. Plan標準構成

計画は `plans/` 直下のライフサイクルバケットに置く。状態はフォルダで持ち、plan.md に状態フィールドは書かない。

```text
plans/
  active/   <YYYY-MM-short-name>/plan.md
  paused/   .gitkeep
  done/     .gitkeep
  archive/  .gitkeep
```

1. バケットが計画の状態の正本。意味は次の通り。
   - `active`: 進行中、または着手前で今のスコープに入っているもの。
   - `paused`: 一時停止。再開予定あり。
   - `done`: 作業完了。まだ評価していない。
   - `archive`: 評価して問題なしを確認済み。参照専用。
2. plan.md に `状態:` フィールドは書かない（フォルダが正本）。
   `分類:`（skill/repo/loop）と `種別:`（新規作成/既存改善/統合整理）は計画の分類なので plan.md 冒頭に書いてよい。
3. 状態が変わったら `git mv` でバケット間を移す。
   - 新規 → `active/` に作る。
   - 一時停止 → `paused/`。
   - 作業完了（未評価）→ plan.md に結果を追記し `done/` へ。
   - 評価OK → `archive/` へ。問題があれば `active/` へ戻す。
4. 空の `paused/` `done/` `archive/` は `.gitkeep` を置く（gitは空ディレクトリを保存しないため）。
5. `plan.md` を計画本文の正本にする。背景、判断、ワークフロー、完了条件はまず `plan.md` に書く。
   `checklist.md` や追加ファイルは、分離した方が読みやすい時だけ作る。

## 3. Ops標準構成

計画を作ったら、`ops/` に種別5フォルダを作る。状態はフォルダにせず、各作業ファイルの中で持つ。

```text
plans/<YYYY-MM-short-name>/
  plan.md
  ops/
    human/        .gitkeep
    ai/           .gitkeep
    repositories/ .gitkeep
    skills/       .gitkeep
    loops/        .gitkeep
```

1. 種別フォルダは空のまま `.gitkeep` を置く。gitは空ディレクトリを保存しないため。
2. 作業は `ops/<種別>/<作業名>.md` に置く。
3. 状態はファイル先頭の `状態:` 行で持つ。フォルダで状態を分けない。

種別は次を使う。

1. `human`: 人間がやること。
2. `ai`: 既存AIに依頼すること。
3. `repositories`: repoの新規作成、既存改善、移動、整理。
4. `skills`: Skillの新規作成、既存改善、統合整理。
5. `loops`: 定期実行、監視、反復処理、自動運用loop。

状態は次を使う。

1. `planning`: 方針検討中、未着手、判断未確定。
2. `ready`: 計画済みで、着手可能。
3. `active`: 実行中。
4. `paused`: 一時停止。
5. `done`: 完了済み。
6. `archive`: 終了、参照専用、または古いもの。

## 4. 配置判断

1. 領域内の考えや調査は `thinking/` に置く。
2. 領域内の実行計画は `plans/active/<計画名>/plan.md` に作り、状態に応じてバケット間を移す。
3. その計画から派生するhuman、AI、repo、Skill、loopの作業は、同じ計画フォルダ内の `ops/<種別>/<作業名>.md` に置き、状態はファイル内の `状態:` 行で持つ。
4. repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
5. Skill正本、registry、logsは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/` を正とする。
6. 計画本文を複数箇所にコピーしない。必要なら相対パスで参照する。
