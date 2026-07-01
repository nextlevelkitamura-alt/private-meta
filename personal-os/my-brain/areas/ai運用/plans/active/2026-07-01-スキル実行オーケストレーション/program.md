分類: skill ／ 種別: 新規作成 ／ 形態: program

# スキル実行オーケストレーション（分配）基盤

## 目的

スキルを最小の実行単位として、**手動**（通常チャット/CLI）と**自動**（時間トリガ）の両方を
"同じ分配ロジック" で回せるオーケストレーション基盤を設計する。
指揮官（中央 Claude）が Orca 経由で 2 ストリームを並走監督し、両者の矛盾を検出しながら進める。

## 全体像

- **Stream1（設計）**: スキル/内容の「分配（distribution/routing）」設計。手動+自動の共通コア＋各アダプタ。
  自動実行は「時間で対象スキルを見つけ (prompt+skill) を engine に流す」。launchd / Orca automations の比較を含む。
- **Stream2（分析）**: デイリー と ダッシュボード の**二重管理**を洗い出し、論点＋選択肢を出す
  （**最終設計はしない**＝後日ユーザーと相談）。daily-digest を「レンダラ」とみなす前提を検証する。
- 不変の背骨は同フォルダ `共有コントラクト.md`。両ストリームはこれに従い、指揮官が差分で矛盾を判定する。
- 関連: `../2026-06-29-OrcaCLI複数エージェント運用/`（本プログラムはその運用の実践でもある）、
  基盤 `skills/coding-task-orchestrator/`（コーディング特化・重複させない対象）。

## 子計画マップ

- **01 分配設計（Stream1）** … active
  次: 設計docを `plans/01-分配設計.md` に。実装はゲート後。
  場所: `plans/01-分配設計.md` ／ worktree: `Private:design-skill-orchestration`
- **02 デイリー二重管理分析（Stream2）** … active
  次: 現状マップ＋論点＋選択肢を `plans/02-デイリー二重管理分析.md` に。設計はしない。
  場所: `plans/02-デイリー二重管理分析.md` ／ worktree: `Private:design-daily-analysis`
- **03 orca-cockpit スキル新設** … 完了（基盤 main 反映）
  成果: 基盤 `skills/orca-cockpit/`（cockpit.sh: up/split/agent/down・並列・codex自動更新）。
  場所: `plans/03-orca-cockpit.md` ／ 反映: 基盤 main（merge d86532f）

## 完了条件（レビュー項目）

- [ ] Stream1: 分配ロジックの推奨案＋対抗案、手動/自動パス、自動実行の接続先（launchd vs Orca automations）、
      既存資産（coding-task-orchestrator / ai-jobs / loop-runbook）との重複回避、段階ビルド計画が `01` にある
- [ ] Stream2: 現状の二重管理マップ、論点、選択肢（最低2案）が `02` にある。**最終設計は含めない**
- [ ] 両者が `共有コントラクト.md` と矛盾しない（指揮官が差分確認）
- [ ] 実装は未着手（承認ゲート前）
