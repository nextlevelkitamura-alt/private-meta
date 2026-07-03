# spawn評価レーン（子09）起動実測レポート

計測日: 2026-07-03／担当: 評価レーン（監督=全体管理者A）／モデル: sonnet5固定
計測環境: orca CLI（`orca terminal create` / `orca worktree ps --json` / `orca terminal wait`）

## 計測方法

1. `orca terminal create --worktree path:<repo> --command "bash <wrapper>" --json` でペイン起動。直前の
   `time.time()` を t0 とする。
2. `orca worktree ps --json` を0.3秒間隔でポーリングし、対象worktreeの `agents[]` に
   `paneKey`（create応答に含まれる）が一致するエントリが現れるまでの経過秒を計測（t0起点）。
   **paneKeyで厳密一致**させることで、共有worktree（Private main）で並走中の他エージェント
   （中間指揮官2など）を誤検知しない設計にした。
3. 計測後は必ず `orca terminal close --terminal <handle>` で片付け。
4. 各条件3回計測・中央値を採用。
5. 再現用ドライバ: `benchmarks/bench.py`（本レポートと同worktreeに保存）。
   実行例: `python3 benchmarks/bench.py --repo /Users/kitamuranaohiro/Private --mode arg --mcp off --label repro`

wrapper生成（CLI落とし穴対策込み）:
```
exec claude "$(cat <promptfile>)" --model claude-sonnet-5 --permission-mode acceptEdits \
  [--strict-mcp-config --mcp-config <empty-mcp.json>]
```
**プロンプトを先頭・`--mcp-config` を末尾**に置く（本任務の指示通り）。この順で実測中
ENAMETOOLONG等の事故は0件だった。

## 基準値（本日既存実測・再掲）

- 旧方式（仕事repo・MCP有効）: 7分無出力
- 手動実証済み高速形（仕事repo・Fable5・MCP無効+引数渡し）: 13秒

## 実測結果（各3回・秒・sonnet5固定）

| # | 条件 (a:MCP / b:起動方式 / c:repo) | rep1 | rep2 | rep3 | 中央値 |
|---|---|---|---|---|---|
| A | MCP無効 / 引数渡し / Private | 7.21 | 2.01 | 3.42 | **3.42** |
| B | MCP有効 / 引数渡し / Private | 5.94 | 8.48 | 5.24 | **5.94** |
| C | MCP無効 / 起動後send / Private | 7.94 | 5.61 | 6.13 | **6.13** |
| D | MCP無効 / 引数渡し / AIエージェント基盤 | 12.23 | 10.39 | 7.67 | **10.39** |

条件Cの内訳（`orca terminal wait --for tui-idle` でready検知→send→ps再ポーリングでagent登録確認）:
readyまで 4.06 / 1.98 / 2.94秒（中央値2.94）、ready後のsend〜agent登録が残り約3.2〜3.9秒。

## 主要な発見

1. **sonnet5 + Private/AIエージェント基盤では a)MCP有効/無効の差はほぼ無い**（中央値3.42秒 vs 5.94秒、
   差は誤差範囲）。理由: 両repoとも `.mcp.json` を持たない（`.mcp.json` は仕事repo専用・CLAUDE.md記載通り）。
   仕事repoの「7分無出力」はMCP機構そのものの重さではなく、仕事repo固有のMCP構成（LINE Reader等）が
   原因という仮説を支持する。→ **AIエージェント基盤/Privateでの`--no-mcp`は起動短縮の主要因ではない**
   （安全側の既定として使う価値はあるが、仕事repoほどの効果は期待できない）。
2. **b)引数渡し vs 起動後sendの差は中央値で約2.7秒**（3.42→6.13秒）。過去事故（送信レースでの
   プロンプト流出・claude不起動20分無検知）を踏まえると、この2.7秒は「レース構造を消すための
   保険料」として妥当な範囲。ただし今回のsend-after実装は`orca terminal wait --for tui-idle`で
   ready確認してから送る安全な手順であり、事故当時の「即send」パターンとは別物（後述）。
3. **c)repo差（Private vs AIエージェント基盤）は中央値で約7秒の開き**（3.42→10.39秒）。同worktree
   起動方式でも repo によって差が出る点は要注意（原因未特定・パスの深さ/ディレクトリ内ファイル数等の
   可能性。次の一手候補）。
4. **【計測手法上の発見】`orca worktree ps --json` の `agents[]` は、プロンプト未投入の裸claude
   （インタラクティブ待機中）を一切拾わない。** 起動直後で `agents` に載るのは「実行中タスクを持つ
   ペイン」のみ。当初「起動後send」の“ready”をps再ポーリングで検知しようとしたところ480秒
   タイムアウトするまで一切検知できず、プロセスをkillして原因を特定した（本レポート作成中に実際に
   ハングを起こして確認済み）。**代替: `orca terminal wait --terminal <h> --for tui-idle` は数秒で
   readyを正しく検知できた**（②へ接続）。

## ②高速化研究（実測 or 見積り）

- **`orca terminal wait --for tui-idle` の活用**（実測・上記条件C参照）: readyペインの検知に
  ps ポーリング（0.3秒間隔の外部プロセス起動を繰り返す）より軽量かつ確実。効果=「起動後send」方式の
  ready検知を正しく行うための必須部品（ps方式は原理的に検知不能）。リスク=低（orca標準コマンド）。
- **`--setting-sources project`（user設定を除外）**（実測・否定的結果）: `--strict-mcp-config`と
  併用し起動したところ、**120秒+追加23秒待っても出力ゼロのままハング**（`orca terminal read`で
  tail 0行を確認）。原因未特定だが、userレベル設定（認証/信頼ディレクトリ等）に依存している疑いが
  強い。効果=不明・実測ではむしろ悪化（無出力ハングは仕事repo7分事故と同じ症状）。リスク=**高。
  単独では採用不可**。試すなら `--setting-sources user,project` などuserを含めた組み合わせから。
- **CLAUDE.mdツリー読み込み量**（見積り）: Private repoの CLAUDE.md/AGENTS.md探索対象は77ファイル
  （`find`実測）。ルート直下のCLAUDE.md自体は4020byte、`~/.claude/CLAUDE.md`は2019byteと小さく、
  今回の起動時間（数秒オーダー）に対して支配的とは考えにくい。効果=小、次点候補。
- **`~/.claude/skills` 量**（見積り）: ユーザー直下33件・33MB。プロジェクト側(AIエージェント基盤)は
  19件。skill本文はfrontmatter読込程度なら軽いはずだが、量が今回計測時間の主要因かは未検証
  （--setting-sourcesが安全に使えないため直接の切り分け実測は次の一手）。
- **warmプール（待機ペイン常備→send注入）**（実測データから逆算）: 条件Cの内訳から、
  「ready後のsend〜agent登録」は約3.2〜3.9秒。ペインを事前に起動して待機させておけば、
  実際に投入したい時点のコストはこの3.2〜3.9秒のみに圧縮できる（起動そのものの3〜10秒は
  隠蔽できる）。効果=大（体感の「送信まで遅すぎ」への直接対策）。リスク=待機ペインの管理コスト
  （どのペインが空きか・タイムアウトでの回収・MCP状態の食い違い）。cockpit.sh側にプール管理を
  持たせるかは設計判断が必要（今回のspawn実装スコープ外・次の一手候補として明記）。
- **`orca terminal wait --for exit`**（未実測・所見のみ）: 今回は使っていないが、bare起動プロセスが
  途中終了するケース（起動失敗）の検知に使えそう。次の一手候補。

## 実施した条件の範囲について（スコープの明記）

「条件別ベンチマーク」を a×b×c の全8通り×3回=24回ではなく、**基準（MCP無効/引数渡し/Private）から
1軸ずつ変えた4条件×3回=12回**に絞って実測した。全数を回すと（MCP有効条件が仕事repoのように
無出力ハングする可能性を考慮すると）評価レーンの時間対効果に見合わないと判断したため。d)モデルは
指示通りsonnet5固定で全条件共通。

## 後片付け

計測に使った全ペインは `orca terminal close` で撤去済み。計測中に1件、手法ミス由来のハングペイン
（発見③参照）が発生したがkill＋closeで復旧済み。既存の稼働中エージェント（Private main上の
中間指揮官2作業ペイン等）への影響なし（paneKey厳密一致のため誤検知・誤操作は発生していない）。

## ③spawn実装の実走評価について

2026-07-03時点、`skills/orca-cockpit/scripts/cockpit.sh` の `cmd_spawn` は **Private main worktree上に
未コミットの変更として存在**（`git status`で`M`）。基盤mainブランチ（コミット履歴）にはまだ入っていない
ため、本worktreeへのfetch+merge対象がまだ無い。①②の実測完了時点でいったん中間報告し、mainへの
コミット/マージを待って③に着手する。

なお `_build_agent_wrapper`（未コミット・cockpit.sh内）を先読みしたところ、生成される起動行は
`exec <base_cmd> "$(cat <promptfile>)"` の順（**プロンプトが`--mcp-config`より後ろ**）になっている。
本レポートの実測では逆順（プロンプト先頭）を使い事故は起きなかったことから、この順序が
「--mcp-configがプロンプト文字列を追加のconfig pathとして飲み込む」落とし穴を再現する可能性がある
（今回はコード先読みのみ・実走未検証）。③の実走評価で最優先の確認項目とする。
