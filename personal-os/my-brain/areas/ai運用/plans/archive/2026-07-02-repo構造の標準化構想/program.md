分類: 横断 ／ 種別: 統合整理 ／ 形態: program
規模: フル

# repo構造と成果物運用の標準化

人間確認方針: 最終一括（危険操作は実行前に個別承認）
差し戻し上限: フル=2・ライト=1（超過は人間へエスカレーション。正本は plan-registry/AGENTS.md）

## 目的

新規repoと既存repoの両方で、計画・成果物・恒久reference・repo registryの責務を混ぜずに運用できる標準を定める。

人間向けの説明・診断は plan内の explain に置き、長く参照する定義・判断基準・参照導線は references に置く。評価と修正指示は評価に残し、archiveは閉じた計画の状態に限定する。

## 非対象

- このprogramの中で、既存repo・既存の知識・legacy・成果物を移動、削除、改名しない。
- 既存repoへ新しい構成を直ちに適用しない。仕事とfocusmapはread-only診断と適用提案までに留める。
- 既存の知識ディレクトリをreferencesへ一括移行しない。
- GitHub作成、commit、push、runtime設定、hook、launchd、本番データの変更を行わない。
- archiveを成果物の保管庫として使わない。

## 正本境界

- このフォルダの program.md: 今回の標準化programと子計画を束ねる唯一の親正本。親plan.mdは置かない。
- personal-os/AIエージェント基盤: Global Skill、repo registry、runtime露出の正本。実体repoの現在位置は projects の物理配置を正とする。
- 対象repo: repo固有のAGENTS、実装、計画、repo-local Skillの正本。横断programはその内容を複製しない。
- 各planの explain と評価: explain は人間向けHTML、評価は完了条件の採点と修正指示の正本。計画専用の長期参照は references に置く。
- 各areaの references: 複数planで長期再利用する定義、判断基準、KPIの定義と外部正本への導線。KPIの現在値そのものは元のSheet、DB、業務システムに残す。

## 役割別コンテキスト

- 実装/共通.md: 実装担当が全子で守る正本、出力、禁止操作、検証の契約。
- 評価/: 評価と修正指示を置く。評価者はplanの完了条件を採点し、統合評価は評価/評価RR.mdに置く。

## 全体像・実行Wave

Wave 1: 01で用語・正本・格納規約を確定する。

Wave 2: 02でplan雛形へ反映し、04で仕事とfocusmapをread-only診断する。

Wave 3: 03で既存のrepo-create移植キットと矛盾しないLevel 2 dry-run仕様へ接続する。

Wave 4: 05で実repoごとの非破壊な適用提案を作り、個別適用が必要なものだけ人間確認へ上げる。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01  成果物とreference正本統一 … 計画
    役割: 契約
    対象repo: /Users/kitamuranaohiro/Private
    並列: 不可
    人間ゲート: なし
    次: area規約とこのprogramの用語を、explain・references・評価の責務へ統一する
    場所: plans/01 ／ 依存: ―
    参照: areas/AGENTS.md と同フォルダの最終計画案HTML

- [ ] 02  計画実行形式を実装・評価へ統一 … 計画
    役割: 統合
    対象repo: /Users/kitamuranaohiro/Private
    並列: 可（04と）
    人間ゲート: なし
    次: plan-ops、harness、hookの実装・評価経路を統一する
    場所: plans/02 ／ 依存: 01
    参照: AIエージェント基盤/skills/plan-ops

- [ ] 03  repo-create Level 2 dry-run接続 … 計画
    役割: 統合
    対象repo: /Users/kitamuranaohiro/Private
    並列: 不可
    人間ゲート: 実repoへのapply、GitHub作成、registry実データ更新は個別承認
    次: 既存のrepo-create移植キットのdry-run契約へLevel 2のarea・plan・出力規約を接続する
    場所: plans/03 ／ 依存: 01, 02
    参照: 2026-07-13-全repoへのAI運用標準移植の子08

- [ ] 04  仕事とfocusmap read-only診断 … 計画
    役割: 診断
    対象repo: /Users/kitamuranaohiro/Private/projects/active/仕事 と focusmap
    並列: 可（02と）
    人間ゲート: なし。read-onlyに限定する
    次: 現在のplan、出力、legacy、KPI正本、AGENTS導線を壊さずに棚卸しする
    場所: plans/04 ／ 依存: 01
    参照: 対象repoの最寄りAGENTS.md

- [ ] 05  既存repo適用提案 … 計画
    役割: 統合
    対象repo: repo無し
    並列: 不可
    人間ゲート: 物理移動、改名、削除、symlink変更、既存成果物のreference昇格は実行前に個別承認
    次: 03と04の結果から、repoごとに差分・順序・保留事項を提案する
    場所: plans/05 ／ 依存: 03, 04
    参照: 01から04のresult packet

## 人間ゲート

- 最終一括: 規約、雛形、dry-run、診断、適用提案が完了した時点で、標準をactiveへ進めるか確認する。
- 個別承認: 既存ファイル・ディレクトリの移動、削除、改名、既存成果物のarea referenceへの移動、symlink変更、Git操作、外部公開、実repoへのapply。

## 完了条件

- [ ] 人間向けHTMLは explain、長期参照は references、評価・修正指示は評価に置く境界が対象規約に一貫して記されている。
- [ ] area referencesの入場条件、KPI正本への導線、既存の知識を一括移動しない方針が文書化されている。
- [ ] archiveが計画の終了状態に限定され、成果物置き場として使われない。
- [ ] plan-ops雛形が空のexplain、references、評価を量産せず、必要時にだけ作る運用を表せる。
- [ ] repo-createのLevel 2 dry-runが既存の移植キットと責務重複せず、既存ファイルを上書きせずに差分を示せる。
- [ ] 仕事とfocusmapのread-only診断と、破壊的操作を含まないrepo別適用提案が揃っている。

## 関連

- 図解: explain/2026-07-19-成果物運用-最終計画案.html
- 既存の実装program: ../active/2026-07-13-全repoへのAI運用標準移植/plans/08-repo-create移植キット.md

## 終了記録

archive時に必須。実行中は記入しない。
