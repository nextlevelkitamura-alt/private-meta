# Private/ — 2領域の入口

`~/Private` 直下に置く管理対象は、次の4つだけに固定する。

1. `AGENTS.md`: この入口ルールの正本。
2. `CLAUDE.md`: `AGENTS.md` への相対symlink。本文コピーは禁止。
3. `personal-os/`: AIエージェント運用基盤、my-brain、計画、進捗、優先順位、意思決定の中枢。
4. `projects/`: 実作業プロジェクトと各リポジトリの置き場。

`~/Private` 直下には、これ以外の可視ファイル、ディレクトリ、リポジトリを増やさない。新しいrepo、資料置き場、実験、作業メモは必ず既存2領域のどちらかに入れる。旧直下repoや旧領域名を復活させない。

隠しメタデータは作業対象にしない。`.git`、`.gitignore`、`.DS_Store`、既存のruntime互換ディレクトリは例外だが、新しい正本、作業場、保管場所として使わない。

このワークスペースは、次の2領域で管理する。

1. `personal-os/`: AIエージェント運用基盤、my-brain、計画、進捗、優先順位、意思決定の中枢。
   - `personal-os/my-brain/`: 自分の考え、領域ごとの判断軸、調査、計画。
   - `personal-os/AIエージェント基盤/`: Global Skill正本、runtime露出、registry、repo履歴ログの正本。
   - `personal-os/my-brain/areas/ai運用/plans/`: Personal OS基盤、横断repo、Global Skill、repo、loopの企画・計画書。
2. `projects/`: 各プロジェクト/リポジトリの置き場。
   - `projects/active/`: 今使うもの。`仕事/`、`focusmap/` などはここに置く。
   - `projects/paused/`: 一時停止中だが残すもの。旧直下repoはまずここへ集約する。
   - `projects/archive/`: 旧資料・終了・参照専用。

repoの現在状態は `projects/active/`、`projects/paused/`、`projects/archive/` の実体配置を正とする。過去の移動、登録、削除理由だけを `personal-os/AIエージェント基盤/repo-registry/logs/` に残す。

`projects/active/` などへの物理移動は、移動前にGit状態、作業ツリー、シンボリックリンク、絶対パス参照、Codex/Claudeの作業場所を確認してから行う。

<!-- AGENT-ROUTER:START -->
## 基本ルール

- このファイルは入口。長い手順、詳細仕様、進捗ログは置かない。
- 自分の考え、領域ごとの判断軸、調査、領域別計画は、原則として `personal-os/my-brain/areas/` に寄せる。
- Personal OS基盤、横断repo、Global Skill、repo、loopの計画や判断は、原則として `personal-os/my-brain/areas/ai運用/` に寄せる。
- 特定repoの計画やrepo-local Skill計画は、対象repo内の `AGENTS.md` と `plans/` を正とし、`personal-os/` に二重管理しない。
- AI運用やスキル整備は、`personal-os/AIエージェント基盤/` に寄せる。
- プロジェクト作業は、原則として `projects/active/` 配下の対象リポジトリの `AGENTS.md` を読む。
- `人生管理/` へ勝手にフォールバックしない。必要な時だけ読み取り専用で参照する。
- 削除、移動、履歴整理、リポジトリ改名は、人間の明示承認なしに実行しない。
<!-- AGENT-ROUTER:END -->

## 判断姿勢

忖度しない。矛盾、盲点、リスクは率直に指摘する。
表面の矛盾に飛びつかず、優先順位、時間軸、両立構造を確認してから判断する。

## 個別注意

- `仕事/` の話題では、必ず `~/Private/projects/active/仕事/AGENTS.md` を読む。旧パス `~/Private/仕事` は互換symlinkとして扱う。
- 正本が曖昧な場合は、作業前にどこを正本にするか確認する。
- 日本語で対話する。
