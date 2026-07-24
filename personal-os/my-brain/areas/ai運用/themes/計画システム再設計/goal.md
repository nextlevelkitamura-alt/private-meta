# Focusmap計画運用のゴール

このファイルは、「計画システム再設計」テーマで今後の検討を始める入口である。このテーマには `theme.md` を置かず、全体目的と現在の決定は `goal.md` に集約する。構想本文の現時点の正本はローカル/Gitであり、将来Tursoへ移す候補の短い状態・活動履歴を先取りして本文同期しない。

## 全体の目的

目的や達成条件を見失わずに進めながら、予定外の単発作業も無理なく扱える計画・実行・可視化の仕組みを作る。

外出中もFocusmapから月間Goalと達成条件を確認でき、AI Sessionは必要なGoal・Focus・Topicだけを取得する。DBとローカル／Gitで同じ情報を編集する二重正本は作らない。

## 現在の決定

### 構成

- このテーマフォルダを正式な検討場所として使い、構想は `concepts/`、Theme固有の実行計画は `plans/` に分ける。
- 全体目的と現在の決定は、この `goal.md` に置く。
- 個別検討は [databaseの保存・参照設計](./concepts/topics/database/storage-and-references.md) と [concepts/topics/ui/](./concepts/topics/ui/) の2つだけに分ける。
- `focusmap/` というトピックフォルダは作らず、Focusmap全体の確認事項は `goal.md` に置く。
- 両方のトピックで使う調査・比較・根拠は [concepts/research/](./concepts/research/) に置く。
- 現段階では `program / plan / 子計画` に分類しない。
- Theme固有のactive計画は [plans/active/](./plans/active/) に置く。AI運用直下の計画箱は廃止し、Themeに属さない実装計画は所有repoの計画箱へ置く。

### 計画運用

- Goalの運用情報はTursoを単一正本とし、編集可能なローカルGoalファイルは作らない。
- 3年Goalは廃止し、月間Goalを中心に、週・日はFocusとして扱う案を優先する。
- Goalに沿う仕事と、単発・定常・予定外のTopicを分け、未分類Sessionは残す。
- DBは毎Promptで読まず、Session冒頭1回と必要時のrefreshを基本にする。
- 詳細Planと制作物はローカル／Gitを正本とし、クラウド表示が必要な場合も一方向cacheにする。
- 実装はまだ開始せず、databaseとuiの検討を個別に進める。

## 検討場所

- [concepts/topics/database/storage-and-references.md](./concepts/topics/database/storage-and-references.md): DBの持ち方、正本境界、同期、AIからの参照・更新方法の正本
- [concepts/topics/ui/](./concepts/topics/ui/): Focusmapでの見え方、操作、PC・スマホの使用体験
- [concepts/research/](./concepts/research/): databaseとuiの両方で参照する調査・比較・根拠資料
- [concepts/discussion-logs/](./concepts/discussion-logs/): 壁打ち・検討から残す記録
- [plans/](./plans/): Theme固有の実行計画。親正本は `plan-0.md`、評価は `evaluations/`、調査・比較・根拠は既定で `concepts/research/` に置く
