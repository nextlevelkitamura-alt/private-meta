# 計画を作る／既存計画へ合流する

## 起動条件・入力・期待出力

- 起動条件: 「この仕事を計画にしたい」「既存計画へ入れたい」。新しい作業の出所をデイリーへ残す必要がある時は、先に `kickoff` を使う。
- 入力: やりたいこと1行、起点pathまたは起点種別、対象repo見当、影響範囲・戻しやすさ。分からない時の質問は `plan-triage` の上限に従う。
- 期待出力: `plan-triage.route/v1`、規模と構成カード、合流先または新規起案候補、書込みの有無。

## 手順

1. `plan-registry/AGENTS.md` と、起点に応じた最寄り `AGENTS.md` を読む。サクッと3条件が全YESなら計画を作らず自己確認・事後報告へ戻す。
2. `plan-triage` を実行し、書込みなしで既存plan・計画箱・handoff要否を解決する。routeのcriteria、JSON、pathをここで再実装しない。
3. `join_existing` は、そのplanを正本として目的・次の一手・完了条件を更新する。`create_new` は指揮官または人間が起案を決めた時だけ、解決済み絶対pathを `plan-ops` の `new-plan.sh` へ渡す。program生成では `実装/共通.md` と `評価/` が同時に生まれる。共通.mdには実装固有の規約だけを書き、program.mdの流れを複製しない。`stop` は書込み0件で人間へ戻す。
4. 生成したplanには目的、現状、方針、検証可能な完了条件と規模を記入する。対象repoへ書くPrivate起点では、routeのhandoff完了後の対象repo sessionだけが書く。
5. programが必要かはregistryの基準で判断する。独立に卒業する子が2本未満なら、単発planのままこのworkflowを完了する。

## 人間ゲート・失敗時・戻り先・完了確認

- 人間ゲート: 移動、削除、runtime変更、push、main反映、外部書込みは明示承認まで実行しない。planning→active昇格も対象計画と上限を人間が確認してから行う。
- 失敗時: path未宣言、候補競合、正本不明、handoff不正は `plan-triage` のstop結果を維持し、root `plans/` を推測・作成しない。
- 戻り先: 子計画が必要なら `manage-program.md`、評価・遷移なら `evaluate-and-transition.md`、実装中レーンの監督なら `cockpit-supervisor`。
- 完了確認: 既存plan優先、plan本文の正本が1つ、必要な完了条件、routeと書込み範囲の一致を確認する。
