# Plan Registry

計画運用を直す時の入口。ここは規約と責務地図を持つが、個別の計画本文・状態・履歴・session-boardの記録は所有しない。計画を全repo共通のフォルダへ集める場所でもない。

## 1. 最初に読む順番

1. 全runtimeの最小ゲートは親の `../GLOBAL_AGENTS.md` §6–7 を読む。
2. この文書で規模・段階・評価の**基準**と、責務、手動/機械の境界を確認する。
3. §6「経路解決（triage決定手続き）」がその基準を依頼へ適用し、対象repo・既存plan・宣言済みの計画箱を**書き込まず**routeとして解決する（端から端の手順は `triage.md`、出力JSONとhandoffの契約は `route-contract.md`）。
4. 解決先の最寄り `AGENTS.md` を読み、物理バケット・テンプレ・area固有の置き方に従う。
5. 雛形生成、子計画マップ更新、静的lintだけを `../skills/plan-ops/` のscriptで行う。

置き場が未宣言、複数候補、正本不明なら新しい共通 `plans/` を作らず、人間に確認する。

## 2. 規模・段階・評価

### サクッと／ライト／フル

- **サクッと**: `GLOBAL_AGENTS.md` §7の3条件がすべてYESの時だけ、計画書なしで実装し自己確認後に事後報告する。1つでもNOまたは不明ならライト以上にする。
- **ライト**: 計画 → 実装 → 評価 → 事後報告。規模は計画冒頭に宣言し、条件を外れたらフルへ引き上げる。
- **フル**: 企画 → 計画 → 実装 → 評価 → （修正 ⇄ 再評価） → 完了。依頼の目的・範囲・完了条件が解決済みならAIが直列で進める。結果を変える未確定の人間判断がある時だけ確認する。

計画やタスクを大課題テーマ（ボードのDB運用データ）へ結び付ける時（AIがテーマを新規作成する時を含む）は、テーマに意図1行（名前）を与えてからDBへ送る。目的・完了条件は任意で、完了条件の正本は計画md側に置く（テーマへ二重に必須化しない）。空の名前だけ拒否し、目的・完了条件の未指定は未記入バッジ扱い。実体は session-board の `board.py theme-add`（`--name` のみ必須・`--purpose`/`--done` は任意）にあり、本規約はその存在を指すだけ（正本＝`../hooks-registry/shared/session-board/AGENTS.md` のboard.pyコマンド節。2026-07-19導入→2026-07-22子03で意図1行へ簡素化）。

計画のフォルダ状態は `planning`（未着手）→ `active`（実装・修正・評価中）→ `done`（最終評価全PASS）→ `archive`（終了記録済みの閉じた参照専用）を正本とする。未解決の人間判断がなければAIが遷移を完了する。`archive` は終了区分と終了記録を必須とし、規約の機械適用は plan-ops に委譲する。

programの子計画マップは `企画 / 計画 / 実装 / 評価 / 修正 / 人間確認 / 完了` を使う。実運用では `実装中`、`評価待ち`、`保留` の注記を許す。program化は、独立に卒業する子計画が2本以上必要になった時に選び、基本は6〜7子まで、OSレベルの大改修だけ10前後を目安にする。

### programの自律完了

- programは親に `完了方針: 最終統合評価で全PASSならAIが完了` を書く。子は評価と必要な修正が全PASSなら閉じ、子ごとに人間確認を待たない。
- 親programは、全子の完了条件と統合評価が全PASSになった時に完了する。結果を変える未確定の人間判断が残る場合だけ `人間確認` を使う。
- 削除・移動・改名・履歴改変・hook/launchd登録・commit・push・main反映・外部公開・本番データ反映・DB migration適用は、子の実行契約に対象・preflight・検証・readback・rollbackを書く。依頼範囲内ならAIが実行し、別の権限や未確定の業務判断が必要な時だけ停止する。

### 評価と自律実行

- サクッとは実装者の自己確認、ライトは1回の評価・差し戻し上限1、フルは独立評価・差し戻し上限2とする。
- 評価はまとめが既定。工程ごとの都度評価は、後続工程がその成果物を直接使う（依存する）工程だけに限る。
- まとめ評価は複数工程・複数子を1本の `評価/まとめ評価RR.md`（または `評価RR.md`）で採点し、全PASSでdoneゲートを満たす。テンプレは `plan-ops/templates/まとめ評価.md`。
- 1計画の `評価/` では `評価RR.md` と `まとめ評価RR.md` を混在させない。done判定は最終ラウンドを1本だけ選ぶため、様式を混ぜると最終ラウンドを取り違えて誤通過し得る。どちらか一方の様式で通す。
- 完了条件は実行前に定義し、対象（ファイルまたはセクション）と「正しい状態」を書く。評価・修正文書のファイル名と置き場は `../../my-brain/areas/AGENTS.md` を正とする。
- AIが自律実行できる操作と停止条件の正確な境界は、全runtimeが読む `../GLOBAL_AGENTS.md` §5–7 を正とする。計画側は承認待ちではなく、検証条件と回復手段を先に定義する。
- programの通常子は独立評価の全PASSで閉じ、親も統合評価の全PASSで完了する。人間確認は、AIだけでは解決できない認証または結果を変える未確定判断がある場合だけ使う。
- 人間の実機目視確認は原則として親の最終一括確認に束ねる。子の段階で目視が必要な場合は実行契約の検証にその項目を明記し、目視結果（日時・確認点・結果）を評価mdへ記録した時だけPASSにできる。記録のない目視は保留として扱う。
- フル計画は、`explain/` の図解HTMLを最新化して構造を透明にする。目的・範囲・完了条件が依頼から解決できれば、確認待ちで止まらずactive昇格・実行開始する。並列子はレーン別のファイル担当とworktree方針を実行契約へ記載済みでなければ起動しない。
- 指揮官は原則3レーンまで、同時評価は全体で2本までにする。超える編成は人間へ明示する。

## 3. 責務地図

| 所有者 | 持つもの | 持たないもの |
|---|---|---|
| `plan-registry/` | この規約、規模・段階・評価の基準、責務地図、経路解決（triage決定手続き）の実体（`triage.md`・`route-contract.md`・`examples/`・`scripts/`） | 個別plan本文、状態、履歴、実行ログ |
| `GLOBAL_AGENTS.md` | 全runtime向けの最小ゲート、自律実行と停止条件 | 詳細な運用手順、テンプレ全文 |
| 対象repoの最寄り `AGENTS.md` | そのrepoの計画箱とローカル規約 | 他repoの置き場判断 |
| `my-brain/areas/AGENTS.md` | areaの物理バケット、テンプレの配置、評価文書、卒業手順 | 規模別評価やSkillの責務判断 |
| `ai運用/AGENTS.md` | Personal OS基盤・横断計画のarea固有配置 | Global共通規約の複製 |
| 経路解決（`triage.md`／`route-contract.md`） | registryの規模基準を適用した書込みなしのroute解決（対象repo・既存plan・宣言済み箱） | 規模基準の定義、ファイル書込み、計画内容、評価合否の判断 |
| `plan-ops` | 雛形、子計画マップ更新、静的lintなど決定的な手続き | 置き場、優先度、評価合否の判断 |
| `plan-create-review` | 利用者の目的を作成・合流・program管理・評価・終了（archive）のworkflowへ振り分け、registryの経路解決（triage決定手続き）/opsへ委譲する一本入口 | 規模基準・route・script・計画本文・評価合否・runtime露出の所有 |
| hook / session-board | 実行記録、通知、sessionの開始・終了 | 計画本文・計画状態、repo/計画箱/評価合否の決定 |

## 4. 手動・script・hookの境界

```text
依頼
  └─ plan-registry: 規模・段階・評価の基準を定義
       └─ 経路解決（triage決定手続き・§6・triage.md）: 基準を依頼へ適用し、書込みなしのrouteを解決
            └─ 指揮官AI: 既存planへ合流するか新規起案するかを判断し、曖昧時だけ人間へ確認
                 └─ plan-ops: 雛形生成・地図更新・lintを機械実行
                      └─ 実装 / 評価
                           └─ hook / session-board: 実行記録と通知だけ
```

- scriptは確定した入力を機械処理する。規模、置き場、評価合否を推測して決めない。
- hookは短い導線を示してもよいが、計画を作成・移動したり、Skillの実行や評価合否を強制したりしない。
- 外部副作用を伴う操作は、scriptやhookの終了コードだけで成功扱いにせず、対象側のreadbackとrollback可否を記録する。

## 5. 物理的な置き場

- repo固有の仕事は、そのrepoの最寄り `AGENTS.md` が宣言する計画箱を使う。
- Personal OS、横断repo、Global Skill、repo、loopの計画は `../../my-brain/areas/ai運用/` を起点にし、`../../my-brain/areas/AGENTS.md` のバケット規約に従う。
- `plan-registry/` へ計画本文、評価結果、移行ログ、session-boardの行をコピーしない。必要な時は正本への相対パスを参照する。

## 6. 経路解決（triage決定手続き）

依頼1件へ§2の規模基準を適用し、対象repo・既存plan・宣言済みの計画箱を**書き込まず**routeとして解決する決定手続き。旧 `plan-triage` skillの実体をこの registry に畳み込んだもので、runtime露出はしない（利用者コマンドでもない）。端から端の手順は `triage.md`、出力JSONとhandoffの唯一の契約は `route-contract.md`、合成例は `examples/`、判定を移設前後で不変に保つ検証は `scripts/`（`validate-route-cases.mjs`・`validate-inbox-contract.mjs`＋`fixtures/`）にある。

### 4判断

1. 規模: §2の サクッと／ライト／フル 基準を当てる。不明はフル側へ倒し、理由を残す。
2. 経路: 下の二段ルーティングで対象repoと計画箱を解決する。
3. 実行形: `direct`（指揮官が直接編集）／`delegated-single`／`delegated-parallel`（ファイル非交差の2 write laneまで）／`integration` から選ぶ。write lane数は direct=0、single/integration=1、parallel=2を上限にする。
4. モデル参照: 正本は `../AIモデル一覧.md`。カードには参照した旨だけを示し、計画本文へ固定しない。

判断はrouteの提示までで、repoへの書込み・レーン起動・外部副作用は行わない。

### 二段ルーティング

- repo内起点: canonical repo → 最寄り `AGENTS.md` → 宣言範囲の既存plan → 宣言箱。repo-registryは読まない。
- Private／headless起点: `../repo-registry/repo概要.md` で担当repoだけを決め → canonical repo → 最寄り `AGENTS.md` → 宣言範囲の既存plan → 宣言箱 → 対象repo所有sessionへのhandoff。領域・project・計画箱は対象repoの `AGENTS.md` だけから決め、registryへ複製しない。
- 既存planが1件なら必ず合流（`join_existing`）。0件かつ宣言箱が一意な時だけ新規を候補（`create_new`）にする。

### fail-closed（exit 3・書込み0）

次は `action=stop`・exit 3・書込み0件で人間判断まで止め、root `plans/` を推測・自動作成しない。

- `REPO_NOT_REGISTERED` / `AGENTS_MISSING` / `PLAN_BOX_MISSING` / `PLAN_BOX_AMBIGUOUS` / `EXISTING_PLAN_AMBIGUOUS` / `HANDOFF_INVALID`

未知codeをその場で増やさず、`route-contract.md` と `scripts/fixtures/` を同じ変更単位で更新する。Private起点で対象repoへ書く前は6-field handoffを満たす新しい対象repo所有sessionを必須にし、既存session IDを移管・reparentしない。

## 7. 関連する正本

- runtime最小ルール: `../GLOBAL_AGENTS.md` §6–7
- areaの物理バケット・テンプレ・卒業: `../../my-brain/areas/AGENTS.md`
- ai運用areaの固有配置: `../../my-brain/areas/ai運用/AGENTS.md`
- 利用者向けの計画管理入口: `../skills/plan-create-review/`
- 経路解決（書き込みなし・triage決定手続き）: 本registryの `triage.md`・`route-contract.md`（§6）
- 機械手続き: `../skills/plan-ops/`
- 実行記録・通知: `../hooks-registry/`
