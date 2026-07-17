# 計画: worker役割別コンテキストと評価フォルダ分離

- 状態: planningのまま実装先行（2026-07-17 人間指示「実行してみて」。昇格を試みたが bucketctl が active上限3/現在5 で正しく拒否＝ドッグフーディング課題#1。人間の②裁定（active/doneの整理）後に正規昇格して帳尻を合わせる）
- pilot: 本計画自身が新構成の第1号 — 単発planだが 実装/共通.md・レビュー/共通.md・評価/ を実験採用し、運用課題を実装結果へ記録する（標準としての単発plan既定は従来どおり隣接のまま）
- 規模: ライト（実装 → 実装レビュー1パス・差し戻し上限1 → 事後報告）
- 起点: 2026-07-17 人間要望「実装者とレビュアーで読むコンテキストを分けたい」「plans内の子計画と評価をフォルダ分けして見やすくしたい」
- 設計合意: 人間向け図解（Artifact）で2026-07-17に合意済み
  - 設計本文: https://claude.ai/code/artifact/0632ee90-8f4d-47e7-8e49-caef90b3109b （v2: 評価フォルダ分離を含む）
- 調査根拠: Exploreサブエージェントによる配線調査（2026-07-17・本計画起票の直前）。要点: worker読み順の組み立ては delegate.py render_task_packet の1箇所に集約・role差は末尾1行のみ・program_run の implement/review は program_path=None で親programを渡していない。
- 人間ゲート: 標準テンプレ変更（新フォルダ 実装/・レビュー/・評価/ の追加）は2026-07-17の対話で承認済み。hook増設なし。pushは別途明示依頼時のみ。

## 方針

1. programフォルダに役割別コンテキストを標準装備する: `実装/共通.md`（実装担当の共通規約）と `レビュー/共通.md`（レビュアーが気をつけること）。program.mdは「何をするか（流れ）」、共通.mdは「その役割がどう振る舞うか」だけを書き、相互コピーしない。
2. 委譲パケットの「最初に読む順番」を役割分岐にする: 実装= 最寄りAGENTS → program.md → 実装/共通.md → 自分の子計画 → references。レビュー= 最寄りAGENTS → program.md → レビュー/共通.md → 対象子の完了条件 → 実装diff。実装にはレビュー/共通.mdを載せず、レビューには実装/共通.mdを載せない。
3. program_run の implement/review が program_path を実際に渡す（現状Noneの欠落修正）。delegate.py 側にも、引数省略時に計画pathから親programを自動推定する導線を入れる（`<program>/plans/` 配下なら検出。program_run以外の直接委譲経路も根治）。共通ファイルと評価フォルダのpathはprogramフォルダから機械導出し、manifestへ新フィールドは追加しない（schema・validate群4箇所の同時改修を避ける）。
4. programの評価NN.md・修正NN.mdの置き場を `plans/` 隣接から `評価/` へ分離する。ファイル名は規約準拠の `NN-〈子名〉-評価RR.md`（RR=ラウンド連番・既存数+1で採番）へ是正する — 現行program_runの `評価{子NN}.md` は子番号をラウンド位置に使う規約不一致のため（計画レビュー01・穴4）。既存ファイルはrenameしない。単発planは従来どおり plan.md 隣接。既存programは旧配置のまま読める両対応（評価/優先→plans/隣接フォールバック）とし、既存計画の移動はしない。
5. hookは増設しない。roles定義（implementer.md / reviewer.md）には「役割別共通ファイルを読む」の一文のみ追加し、パス直書きはしない。
6. 計画確定後・実装前に、read-onlyサブエージェントによる計画レビュー（改善提案つき）を実施し、提案の採否を記録してから着手する（2026-07-17 人間指示）。記録先は `評価/計画レビュー01.md`。→ 実施済み: 条件付きGO・提案7件全採用・本計画へ反映済み（2026-07-17）。
7. pilotの限界を明記する: 単発planである本計画の 実装/共通.md はharness配布に載らない（programフォルダ導出のため）。pilotで検証するのはテンプレ構成・評価/運用・bucketctl遷移までで、読み順の役割分岐はテストと次の実programで検証する（計画レビュー01・穴6）。

## 変更対象（見込み）

- agents-registry/harness/delegate.py（読み順の役割分岐・共通ファイル/評価pathの導出・親program自動推定）
- agents-registry/harness/program_run.py（program_path受け渡し・評価保存先と命名の是正・commit_sync追従）
- skills/plan-ops/scripts/bucketctl_core.py（evaluation_passes を 評価/→直下 の順の両対応探索へ）※計画レビュー01の致命穴1
- skills/plan-ops/scripts/new-plan.sh（program生成時に 実装/共通.md・レビュー/共通.md・評価/ を生やす）
- skills/plan-ops/templates/program.md・実行指示.md・子計画.md、雛形2枚新設（program-実装共通.md・program-レビュー共通.md）
- skills/plan-ops/scripts/program_lint_core.py（実装/レビュー共通mdの存在チェック・評価/両対応）※宿主はplan-lintでなくprogram-lint（計画レビュー01・穴5訂正）
- personal-os/my-brain/areas/AGENTS.md（評価・修正文書の置き場規約: programは評価/・単発は隣接・旧配置は読み取り互換）
- skills/plan-create-review/workflows/create-or-join.md・review-and-transition.md（生成物と読み物の明文化）
- agents-registry/roles/implementer.md・reviewer.md（一文追加）
- テスト追従: harness tests（test_delegate.py・test_program_run.py）・plan-ops __tests__（test_bucketctl.sh・test_program_lint.sh 含む）・必要ならplan-closeout
- hooks-registry/shared/session-board/tests/test-shims.sh ※修正01でのスコープ拡張（e7bc9c5の期待値追従漏れ＝既存不整合の解消・本計画diffとは独立）

## 完了条件（レビュー項目）

- [x] `new-plan.sh` のprogram生成を機械実行すると、出力先に program.md・実装/共通.md・レビュー/共通.md・評価/（.gitkeep）が生まれ、全てgit追跡可能
- [x] program配下の子への委譲で、implementerパケットが「AGENTS → program.md → 実装/共通.md → 子計画 → references」の順で出力され「レビュー/共通.md」の文字列を含まない。program無し（単発plan）では共通.md行が出ず従来のまま（両方テストで固定）
- [x] 同条件のreviewerパケットが「AGENTS → program.md → レビュー/共通.md → 対象計画の完了条件 → diff」で出力され「実装/共通.md」を含まない。explorerは従来どおり（テストで固定）
- [x] program_run の implement/review が program_path を渡し、パケットの「親program」が実pathになり、同一task_idのmanifestも最終的に実pathを保持する（None欠落の解消をテストで固定）
- [x] (a) program_run が評価・修正を `<program>/評価/` へ規約準拠名 `NN-〈子名〉-評価RR.md` で保存し commit_sync も追従する (b) bucketctl の evaluation_passes が 評価/→直下 の順で探索し、旧配置計画とpilot（本計画）の両方で done判定が正しい（test_bucketctl.shで固定） (c) program-lint が旧配置除外を維持しつつ役割別共通mdの存在チェックを行う (d) 実在検証: 2026-07-15-計画立案実行完了基盤 が lint違反0・閉鎖ゲート判定不変
- [x] manifest schema・manifest.py・planctl MANIFEST_TYPES・plan-closeout MANIFEST_REQUIRED に差分がない（新フィールド不追加の確認）
- [x] hooks登録（~/.claude/settings.json・hooks-registry/codex/hooks.json）に差分がない
- [x] 既存テスト（harness・plan-ops・plan-closeout・session-board）が全緑＋新分岐のテストが追加されている
- [x] areas/AGENTS.md の評価・修正文書節が新規約（programは評価/・単発は隣接・旧配置は読み取り互換）を宣言し、plan-registry側の委譲記述と矛盾がない

## 実装結果

- status: completed（評価02 全PASS 9/9・2026-07-17）
- base_commit: 6caf9b1 ／ result_commit: cb7e251（実装20ファイル）+ 6a2c2b2（修正01: test-shims.sh追従）
- changed_paths: harness（delegate.py・program_run.py・tests×2）、plan-ops（bucketctl_core.py・program_lint_core.py・new-plan.sh・templates×5・__tests__×2・workflows/scaffold-and-update.md）、plan-create-review workflows×2、roles×2、areas/AGENTS.md、session-board tests/test-shims.sh（修正01スコープ拡張）
- tests: delegate 11・program_run 15・plan-ops 189・plan-closeout 62・session-board python（13/14/43 他）・test-session-board.sh 80・test-shims.sh 60 — 全緑（評価02で独立再実測済み）
- レビュー履歴: 計画レビュー01（条件付きGO・提案7件全採用・致命穴1件を着手前に解消）→ 実装 → 評価01（8/9・項目8 FAIL）→ 修正01 → 評価02（全PASS）。差し戻し1回＝ライト上限内。
- 訂正: 実装者（指揮官）の評価01時点の申告「shell 2本 緑」は誤り（パイプでexit codeを潰した誤測定）。レビュアーが検出し、以後はexit code直検で再実測。
- 指揮官裁定の記録: RR採番はlegacy旧命名 `評価NN.md` を算入しない（数字が子NNでありラウンドではないため。衝突なし・commit_syncは両方拾う）。
- ドッグフーディング課題（新構成を本計画自身で使った所見）:
  1. 課題#1: active昇格をbucketctlが正しく拒否（上限3・現5件・人間裁定を要求）。②裁定が全計画の入口ボトルネックであることが実運用で再確認された。本計画はplanningのまま人間指示で実装先行し、②裁定後に正規昇格して帳尻を合わせる。
  2. 課題#2: 「計画レビュー」の記録置き場が規約未定義だった。本pilotは `評価/計画レビュー01.md` に置いた — 違和感なし。標準化候補として次の規約更新に載せる。
  3. 課題#3: unit（test_common.py）とE2E（test-shims.sh）の期待値更新が片方だけ行われる事故（e7bc9c5）が潜在していた。案内文の仕様変更時はunit/E2E両方の追従をセットにする。
  4. 課題#4: 単発planのpilotでは共通.mdがharness配布に載らない（方針7に明記済み）。読み順分岐の実地検証は次の実programで行う。
- pilot遷移ゲート実測: 評価02（全PASS）保存後、bucketctl evaluation_files が 評価/評価01.md・評価02.md を認識し evaluation_passes=True（最新ラウンド判定・計画レビュー01.mdを誤認しない）。done遷移の機械要件を満たす。
