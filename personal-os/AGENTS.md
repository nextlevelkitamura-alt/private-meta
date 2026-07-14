# Personal OS

AIエージェント運用・思考・計画・意思決定の中枢。実装ではなく「運用」のrepo。
現在の状態は当日デイリー/session-board、恒久ルールは `AIエージェント基盤/GLOBAL_AGENTS.md`、計画は各areaまたは対象repoを読む。

## フォルダ（どこに何があるか。詳しくは各 AGENTS.md）
- `my-brain/` … 自分の考え・判断軸・調査・領域別計画を明文化する場所
  - `areas/` … 領域ごと（ai運用 等）。計画はここで育て、成熟したらrepoへ卒業（正本 `areas/AGENTS.md`）
- `AIエージェント基盤/` … エージェントが動く土台の正本（Skill・loop・hook・registry・global指示）。git構成の一望は `AIエージェント基盤/git-registry/git-overview.md`
- `AGENTS.md` … この入口ルールの正本／`CLAUDE.md` … それへの相対symlink

## 配下すべてが守ること（絶対ルール）
- 危険操作（削除・移動・改名・履歴整理・正本変更・破壊的git）は人間の明示承認なしにやらない。
- secret / token / credential / 環境変数の値は、表示・記録・commitしない。
- 正本は一つ。同じ本文を複数箇所へコピーして二重管理しない。
- push は明示依頼時だけ。`git add -A` を避け、パスを指定してcommitする。
- 構成やルールを変えたら、関連する `AGENTS.md`・計画・logs を同じ作業で更新する。
- 忖度しない。矛盾・盲点・リスクは率直に指摘する。

## 迷ったら（どこを読む・どこに置く）
- my-brain を触る → `my-brain/AGENTS.md`（領域別の計画・状態語彙は `my-brain/areas/AGENTS.md` が正本）
- Skill・loop・hook・registry・global指示 → `AIエージェント基盤/AGENTS.md`
- 特定repoの実装・計画・repo-local Skill → そのrepoを正本にする（personal-osに二重管理しない）

## 新しく足すときの手順
1. 上の「フォルダ」一覧に1行足す。
2. そのフォルダに `AGENTS.md`（＋`CLAUDE.md`→`AGENTS.md` の相対symlink）を置き、固有の構成はそこに書く。入口には書かない。
