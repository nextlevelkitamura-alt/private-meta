親計画: ../program.md ／ 分類: 横断 ／ 種別: 診断
規模: フル
形態判定: Program子 ／ 理由: 実repoの診断結果を非破壊の適用提案へ束ねるため
並列: 可（02と） ／ 差し戻し上限: フル=2
人間ゲート: なし。read-onlyに限定する

# 仕事とfocusmapのread-only診断

## 目的

実践的な仕事repoと実装系のfocusmapを読み取り専用で比較し、標準を適用する順序と保留事項を証拠付きで示す。

## 非対象

- 対象repoのファイル、symlink、Git状態、registryを変更しない。
- legacy、知識、出力の移動・改名・削除を提案の名目で実行しない。
- KPIの値やsecretを収集・表示しない。

## 現状

仕事repoは実際の業務運用を含み、focusmapは実装系の構成を持つ。両者を同一雛形へ即時変換せず、既存の正本とplan導線を確認する必要がある。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private/projects/active/仕事 と focusmap
- 実行形: delegated-parallel
- 最初に読む順番:
  1. 各対象repoの最寄りAGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この子計画
  5. repo-create移植キットのaudit-repo契約
- 依存成果: 01の正本規約
- 変更可能範囲: この子planのoutputsに置く診断レポートだけ
- 変更禁止範囲: 仕事、focusmap、registry、runtime、Git設定、symlink
- ファイル担当マップ: 仕事診断laneは仕事のread-only調査、focusmap診断laneはfocusmapのread-only調査。書込み担当は置かない
- worktree方針: 不要
- 維持する契約: 実体配置を現在状態の正本とし、registryは索引・履歴として扱う。secretとKPI現在値を出力しない
- 検証: 各laneのresult packetで対象path、読んだAGENTS、検出事項、変更0、secret値0を確認する
- 停止・エスカレーション条件: AGENTSの正本又はcanonical pathが曖昧な場合、read-onlyでは確認できない認証境界に達した場合
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. 仕事はarea、plans、業務成果物、legacyの関係を、focusmapは実装・docs・plans・生成物の関係を分けて確認する。
2. 各repoで、現在の計画正本、成果物の置き場、恒久reference候補、KPI外部正本への導線、AGENTSとCLAUDEの整合を確認する。
3. 見つけた差分はこのplanのoutputsに日付-用途名で報告し、対象repoには書き込まない。
4. 移動・改名・削除・symlink修正が必要な候補は、対象、理由、影響、rollbackを明記して05へ渡す。

## 完了条件

- [ ] 仕事とfocusmapの各診断がread-onlyで完了し、変更0と読んだ正本が記録されている。
- [ ] 各repoについて、適用候補と、人間承認が必要な移動又は変更候補が分離されている。

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
