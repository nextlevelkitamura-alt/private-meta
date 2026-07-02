分類: skill ／ 種別: 新規作成

# 03 orca-cockpit スキル新設

## 目的

Orca分割コックピット（左=計画+監督 / 右上=実装 / 右下=レビュー）の構築・駆動を、
決定的部分はスクリプト、判断・指示はAI/人で回すGlobal Skillを作る。
手動ドライブ（tool往復）の遅さ・脆さをスクリプト化で解消する。

## 決定事項（スパイクで実測済み）

1. 分割: `vertical`(左右) → 右を `horizontal`(上下) で「左 / 右上 / 右下」。3/4ペインtemplate。
2. 既定: 左=計画(claude) / 右上=実装(codex gpt-5.5 medium) / 右下=レビュー(codex gpt-5.5 medium)。
3. title: worktree `--display-name`=計画名（モバイルのタブ名に反映）。**ペイン個別の恒久タイトルは不可**
   （codex が pty title を cwd basename に上書きし続けるため）＝役割は「位置」で固定。
4. 構成: `SKILL.md` ＋ `scripts/cockpit.sh`（サブコマンド up/new/split/agent/send/title/status）。
   **references は作らない**（実行ロジックはscript、細部は `cockpit.sh help` に集約。説明の二重化を避ける）。
5. 起動プロンプト（codex update / claude browser）は「読んで判定」で潰す（矢印の盲打ちにしない）。

## 成果物

1. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/orca-cockpit/SKILL.md`
2. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/orca-cockpit/scripts/cockpit.sh`
3. logs: `global-skill-registry/logs/created/2026-07/…`、catalog(meta) 更新。runtime露出=symlink。

## 完了条件（レビュー項目）

- [ ] `cockpit.sh up` で3ペイン構築＋既定agent起動が動く（スモーク）
- [ ] 役割 / モデル / effort を引数で上書きできる
- [ ] `SKILL.md` が skill-creator 規約（入口 / 手順 / 安全 / ~110行）に沿う
- [ ] `coding-task-orchestrator` との棲み分けが明記され重複が無い
- [ ] Stream1（01 分配設計）と矛盾しない（title機構・agent起動法を共有）

## 関連

- 親: `../program.md`（本programのStream1=01が抽象設計、本03がその具体機構）。
- 上位Skill: 基盤 `skills/coding-task-orchestrator/`。
