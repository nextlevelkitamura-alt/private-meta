# triage workflow

やりたいこと1件を、規模・経路・実行形・モデル参照の4判断と構成カードへ変換する端から端までの手順。plan-registry の経路解決（triage決定手続き）の実体で、AGENTS.md §「経路解決」から参照される。経路の詳細と出力fieldは `route-contract.md` を正とする。

## Step 1: 入力と起点を固定する

1. 原文、起点path、対象repo見当、影響範囲、戻しやすさを記録する。
2. 対話中だけ、不明な影響範囲・戻しやすさを最大2問で確認する。headlessは質問せず保守的に判定する。
3. 起点pathがcanonical repo内なら `repo`、Private入口なら `private`、巡回なら `headless` とする。
4. ここではファイルを作らず、route入力を固定する。

## Step 2: 規模を判定する

規模語彙と人間ゲートの正本は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md` §7。

1. 変更1〜2ファイル、1手で戻せる、人間ゲートなしの全てがYESなら `サクッと`。
2. それ以外で1レーン完結かつ完了条件3行に収まるなら `ライト`。
3. 独立する子計画2本以上、複数レーン、複数の人間ゲートなら `フル`。
4. 不明はフル側へ倒し、判断理由を残す。

## Step 3: 二段ルーティングする

### repo内起点

1. `git rev-parse --show-toplevel` 相当でcanonical repoを固定する。
2. 起点から最寄りの `AGENTS.md` を読む。repo-registryは読まない。
3. AGENTSが宣言した検索範囲だけで既存planを先に検索する。
4. 一意な既存planがあれば `join_existing`。一致0件なら宣言済み計画箱を新規候補にする。

### Private / headless起点

1. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/repo概要.md` から担当repoだけを決める。
2. 対象repoのcanonical pathと最寄り `AGENTS.md` を解決する。
3. 領域・project・検索範囲・計画箱はAGENTSだけから決める。registryへ複製しない。
4. 既存plan検索と新規候補の判定はrepo内起点と同じにする。
5. 対象repoへの書込みが必要なら `handoff_required=true` とし、新しい対象repo所有sessionを要求する。

### fail-closed

次は `action=stop`、exit 3、書込み0件にする。

1. `REPO_NOT_REGISTERED`: Private起点で担当repoが解決しない。
2. `AGENTS_MISSING`: canonical repoに適用可能なAGENTSがない。
3. `PLAN_BOX_MISSING`: 計画箱が宣言されていない。
4. `PLAN_BOX_AMBIGUOUS`: 同順位の箱が複数ある。
5. `EXISTING_PLAN_AMBIGUOUS`: 合流候補が複数あり正本を決められない。
6. `HANDOFF_INVALID`: 必須field欠損、別repoのworktree、snapshot不一致。

## Step 4: 実行形とモデルを判定する

1. 実行形は `direct`（指揮官が直接編集）／`delegated-single`（worker 1体へ委譲）／`delegated-parallel`（ファイル非交差の2 write laneまで）／`integration`（統合検証）から選ぶ。
2. 必要役割は implementer を基本に、検証が独立する時だけ reviewer、経路や所有が未確定な時だけ explorer を足す。write lane数は direct=0、single/integration=1、parallel=2を上限にする。
3. worktreeはread-onlyまたはdirectなら `不要`、writeを委譲するなら `task-scoped`。parallelはレーン別の変更可能範囲とworktree方針が計画に記載済みでなければ選ばない。
4. レビューはサクッと=`自己`、ライト=`1pass`、フル=`full`を既定にし、子の束ね方は計画へ `都度/一括` として記す。モデルの正本は `../AIモデル一覧.md`で、カードには参照した旨だけを示す。
5. Orcaは任意adapterであり、このカードの既定出力・起動操作には含めない。

## Step 5: route JSONと構成カードを出す

1. `plan-triage.route/v1` の全fieldを固定順で返す。
2. 候補path・findingは辞書順にし、timestampやsecret値を含めない。
3. 構成カードには次を固定順で載せる。

   ```text
   規模:
   形態: quick / plan / program
   対象repo:
   計画置き場:
   実行形: direct / delegated-single / delegated-parallel / integration
   必要役割:
   write lane数:
   worktree: 不要 / task-scoped
   レビュー: 自己 / 1pass / full ＋ 都度 / 一括
   人間ゲート:
   判定理由:
   ```

   Orcaのペイン編成は、ユーザーが選んだ時だけ任意adapterとして別途提案する。
4. stop時は計画スケルトンを作らず、人間が決める1点だけを返す。

## Step 6: 計画スケルトンを提案する

1. `サクッと` は計画書なし。
2. ライト以上は、解決済みの絶対pathを `../skills/plan-ops/scripts/new-plan.sh --out <path>` へ渡す案を出す。
3. `bucketctl` はrepo AGENTSがroot bucket計画と宣言した対象だけに使う。
4. 領域plan、`docs/ai/plans/active` などrepo固有箱へroot bucket操作を適用しない。
5. Private起点の実書込みはhandoff完了後の対象repo sessionが所有する。

## Step 7: 完了確認

1. route JSONがcontractを満たす。
2. 新規作成より既存plan合流が優先されている。
3. 推測したroot plans、別repoのworktree、計画本文の複製が0件。
4. plan-triage自身によるファイル変更・レーン起動・外部副作用が0件。
