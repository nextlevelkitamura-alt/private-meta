# 子04: 立案強制hookの要否判断と設計

親program: `../program.md` ／ 子計画: `../plans/04-立案強制hookの要否判断と設計.md`
作成: 2026-07-22 ／ 役割: implementer（判断・設計のみ。hook登録は人間ゲート・本文書では登録しない）

判断結果（結論先出し）: **見送り推奨**。PreToolUseでの立案強制hookは実装しない。
理由の核: 実装系ツール呼び出しの瞬間に「サクッと（3条件YES）」と「ライト以上」を区別する信号が無く、正当な軽微実装のほぼ全てで誤検知するため、警告疲れで無視・無効化され、規律に対してむしろ有害。穴は子03の朝会（日次・人間ゲート・全文脈）と既存register-and-guideの開始時リマインドで埋まる。

## 0. 人間判断（2026-07-22・最終）

上記の見送り推奨に対し、人間は **段階1（警告のみhook）の採用** を選択した。§3.2 の設計どおり
`hooks-registry/events/pre-tool-use/guard-plan-gate.py`（＋対の `guard-plan-gate.md`）を実装済み。
免除（.md・plans/references/評価/scratchpad・active計画あり・session1回）を効かせ、denyもaskもせず警告のみ・exit0。
単体検証済み（.git+active計画→免除／なし→警告1回／別session→再警告／異常入力→exit0）。
**未登録**（settings.json / codex hooks.json に無い＝作用しない）で、登録は GLOBAL_AGENTS.md §7 の人間ゲート＝残る承認事項。
以下は判断材料として残す分析（見送り側の論拠。段階を上げる／戻す判断の土台）。

---

## 1. 現状整理

### 1.1 いま動いているhook（PreToolUse周辺）

- `register-and-guide.py`（UserPromptSubmit・matcher `""`＝全プロンプト）: session-board枠を登録し、目標未記入なら開始ガイド、記入済みなら短いミラーを注入する。`register_prompt()` は注入テキストを `print` するだけで **exit0＝非ブロック**。計画の有無は一切見ない。
- `guard-plan-bucket-move.py`（PreToolUse・matcher `^Bash$`）: Bash内の生 `mv` / `git mv` が `plans/<bucket>` を対象にする時だけ `permissionDecision: deny` を返す。それ以外は exit0・stdoutなし。**唯一のdeny型ガードだが、対象は「曖昧さの無い危険操作」に限定**され、判断を要する「計画を立てたか」は見ない。
- `capture-subagent-detail.py`（PreToolUse・matcher `^(Agent|Task)$`）: subagent起動の詳細を捕捉するだけ。ブロックしない。
- その他: `reconcile-and-notify`（SessionStart）・`mark-wait` / `guard-plan-closeout`（Stop）・`sync-subagent-status` / `verify-plan-worker`（Subagent）。いずれも状態同期かmanifest検査で、通常セッションの実装を止めない。

### 1.2 「計画を立てずに実装するのを止める」hookは無い

- 実装（Edit/Write/MultiEdit）に対して、対象repoのactive計画/起票の有無を確認してブロックまたは警告するhookは **存在しない**。
- 強制力は「規約（GLOBAL_AGENTS.md・各AGENTS.md）＋AIの規律」のみ。register-and-guideは毎ターン開始時にガイド/ミラーを注入するが、計画未策定を検知する仕組みは持たず、しかも非ブロック。
- GLOBAL_AGENTS.md §7 が「サクッと」を **3条件AND**（①変更1〜2ファイル ②容易に戻せる ③人間ゲートなし）で定義し、1つでも外れたらライト以上として計画を置くと規定するが、**この判定の適用はAI任せ**。機械的に強制する経路は無い。

### 1.3 発見した文書の矛盾（読むだけ・未修正・要人間確認）

- `hooks-registry/events/pre-tool-use/guard-plan-bucket-move.md` と同フォルダ `AGENTS.md`/`CLAUDE.md` は「Claude/Codexの登録は承認セットまで未適用」と記す。
- しかし `~/.claude/settings.json`（110行目）では `guard-plan-bucket-move.py --runtime claude`（matcher `^Bash$`）が **既に登録済み**。上位 `hooks-registry/AGENTS.md` も「guard-plan-closeout guardが稼働」「guard-plan-bucket-moveは…止める」と稼働前提で書く。
- つまり pre-tool-use配下の説明書が古い前提（未登録）のまま。**変更禁止範囲なので本子では直さない**。子04所掌外だが、hooks-registryの正本整合として別途人間確認を要する残課題。

---

## 2. 要否判断

### 2.1 立案強制がもたらす安全性（プラス面）

- 計画バケットを経ずに実装が始まる「規律のすり抜け」を機械的に検知でき、AIの当たり外れに依存しない。
- 特に無人・headless・subagentが暴走的に多ファイルを書き換える事故を、書き込み前に一段止められる可能性。

### 2.2 正当なサクッとへの摩擦（マイナス面）と誤検知リスク（具体）

PreToolUseのEdit/Write時点で持てる情報は「今から書く1ファイルのpath」と「cwd」だけ。ここに構造的な限界がある。

- **3条件は「ターン単位」でしか判定できず、Edit単位では判定できない**。「変更1〜2ファイル」は、最初のEditの瞬間には後続で何ファイル触るか不明。「容易に戻せる」「人間ゲートなし」も編集内容と作業全体を見ないと決まらない。→ 最初のEditは常に「まだサクッとか不明」で発火してしまう。
- **「対象repoに紐づくactive計画」を機械解決できない**。GLOBAL_AGENTS.md §6は計画箱の解決を「repo-registry → 最寄りAGENTS.md → 宣言済み計画箱、曖昧なら人間に確認」と明示的に人間ループ前提で規定する。~/Privateでは計画が `areas/*/plans/active/` と repo-local `plans/` に分散し、「この編集に対応するactive計画があるか」を一意に導くpathが無い。
- **「当日起票」は信号にならない**。session-boardはUserPromptSubmitで **全セッションを自動起票**する（register_promptの主経路）。よって「当日起票あり」はほぼ常にYES＝常時通過＝無意味。逆に「計画が当日作られたか」に絞ると、既存active計画を進める正当な実装まで誤検知する。
- **具体的な誤検知の場面**:
  - タイプ修正・1ファイルのconfig微調整など、正当なサクッとの最初のEditで発火（軽微実装の多数が該当）。
  - 計画自身の成果物（references/評価/plan.md）の編集で発火。まさに本タスク（この文書を書くEdit）が該当し、これに対応する「別のactive計画」は存在しない。
  - scratchpad・一時ファイルの編集で発火。
  - 親計画から派遣されたsubagent実装者で発火（計画は親側に在るが、subagentのcwd/文脈から解決できない）。
- 結果として **正当な軽微実装のほぼ全てで発火**し、警告疲れ→無視、あるいは人間による無効化を招く。これは「hookは非ブロッキング」「曖昧さの無い危険操作だけ止める」という hooks-registry の既存規律（guard-plan-bucket-moveの設計思想）にも反する。

### 2.3 子03の朝会が代替になるか

- 子03はdaily-startを「①active計画の工程進捗要約 ②今日進める計画の選択 ③次工程のAI割り振り案の提示と人間承認 ④繰越し・滞留質問の確認」へ改訂する。
- これは **日次・人間ゲート・作業全体の文脈** で「今日の実装が計画に紐づいているか」を確認する経路であり、PreToolUseに欠けている粒度（ターン/日単位・人間判断・全文脈）をちょうど埋める。
- 「立案してから実装に入る」の担保としては、Edit単位のブロックより朝会の計画選択・割り振り承認のほうが誤検知なく機能する。→ **朝会は妥当な代替**。
- 加えて register-and-guide が毎ターン開始時（UserPromptSubmit＝プロンプト全文が読める）にガイド/ミラーを注入済み。助言レイヤは既に正しいイベントに存在する。

---

## 3. やるなら最小設計案（採用しない前提の参考設計）

将来「それでも機械的な一段が欲しい」となった時のための、摩擦を最小化した段階案。**本子では登録しない（人間ゲート）**。

### 3.1 段階0（推奨する唯一の低リスク版・ただし別所掌）

- 新規PreToolUse hookを作らず、**register-and-guideの注入テキストにサクッと3条件と計画ゲートの一文を足すだけ**（UserPromptSubmit・非ブロック・プロンプト全文が文脈として使える）。
- これは新hookでなく既存hook＝子03/register-and-guideの territory。摩擦ゼロ、誤検知ゼロ、警告疲れなし。強制ではなく助言の質を上げるにとどまる。

### 3.2 段階1（もし新hookを作るなら・警告のみ）

- イベント: `PreToolUse`、matcher `^(Edit|Write|MultiEdit)$`。
- 判定: `tool_input.file_path` と `cwd` を読む。次を **免除**して残りだけ警告する。
  - パスが `plans/`・`references/`・`評価/`・`scratchpad`・`.md`（計画/文書系）→ 免除。
  - cwd/pathが対応repoの `plans/active/` を持つ → 免除（active計画がある＝立案済みと見なす）。
  - subagent実行（payloadで判別）→ 免除（親計画で管理済み）。
- 出力: 上記いずれにも当たらない時だけ、`additionalContext`（Claude）/ stdout に **警告文のみ**（「この実装に紐づくactive計画/起票が見当たりません。サクッと3条件（1〜2ファイル・容易に戻せる・人間ゲートなし）を全て満たすか確認し、外れるなら計画を置いてください」）。**deny せず exit0**。
- 発火抑制: セッション内で一度警告したら再警告しない（guard-plan-closeoutの `stop_hook_active` 相当のフラグ）。警告スパムを避ける。

### 3.3 サクッと免除の経路（3条件YESの明示免除）

- 段階1の「.md/計画系path・active計画あり・subagent」を免除条件とするのが自動免除の実体。ただし前述の通り 3条件そのものは編集時点で機械判定できないため、**完全な自動免除は不可能**。
- 自己申告型（AIが `SAKUTTO=1` 等のマーカーで免除宣言）は、容易に空打ちでき摩擦だけ残るので採らない。

### 3.4 強度を上げる段階（将来・要人間再承認）

- 段階2: 警告に加え、`permissionDecision: ask`（denyでなく確認）で1回だけ人間確認を挟む。
- 段階3: 特定条件（例: 同一ターンで3ファイル目のEditに到達＝サクッと閾値超過が確定した時点）でのみ `ask`。ターン跨ぎのファイル計数状態を持つ必要があり、複雑さとのトレードオフ。
- いずれも誤検知率と警告疲れの実測を段階1で確認してからでないと進めない。段階を飛ばして deny から始めない。

---

## 4. 推奨と結論

### 4.1 推奨: 見送り

立案強制hook（PreToolUse deny/警告）は **実装しない**。根拠:

1. Edit/Write時点に3条件（ターン単位の性質）を判定する信号が無く、正当なサクッとの最初の編集でほぼ必ず誤検知する。
2. 「対象repoのactive計画」を一意解決するpathが無く（箱解決は人間ループ前提）、「当日起票」は全セッション自動起票で信号にならない。
3. 誤検知多発→警告疲れ→無視・無効化で、規律に対しむしろ有害。hooks-registryの「非ブロッキング・曖昧な操作は止めない」規律にも反する。
4. 埋めたい穴（立案せず実装）は、子03の朝会（日次・人間ゲート・全文脈での計画選択と割り振り承認）と、register-and-guideの開始時リマインドで、より低摩擦かつ誤検知なく担保される。

### 4.2 代替で穴が埋まる根拠（子03との整合）

- 子03の朝会④工程で「今日進める計画の選択」と「次工程のAI割り振り案の人間承認」を通すため、実装は計画選択を経てから配られる。Edit単位のブロックより上流・人間ゲートで立案を担保する。
- 望むなら段階0（register-and-guideの注入文にサクッと3条件＋計画ゲートの一文を追加）で助言を薄く強化できるが、これは新hookでなく既存hook＝子03/register-and-guideの所掌。本子では実施せず、必要なら子03側の判断に委ねる（提案として記録）。

### 4.3 実装する場合の人間ゲートと最小手順（本子では実行しない）

将来もし段階1を実装する判断になった場合に限り、以下は全て **人間の明示承認が必要**（GLOBAL_AGENTS.md §7「hook/launchd登録は規模に関係なく人間承認」）。本子は登録しない。

1. `hooks-registry/events/pre-tool-use/` に `guard-plan-gate.py`（警告のみ・exit0）＋同名 `.md` を対で新設。
2. `~/.claude/settings.json` の `PreToolUse` 配列に matcher `^(Edit|Write|MultiEdit)$` のエントリを追加（既存 `^Bash$`・`^(Agent|Task)$` の隣、guard-plan-bucket-moveと同形式）。
3. Codexは `hooks-registry/codex/hooks.json` に対応エントリを追加し、人間が `/hooks` で再trust。
4. `shared/session-board/registered.sh` で登録を確認。
5. 検証: 計画なし実装→警告が出る／サクッと（.md・active計画あり・subagent）→通過、を単体で確認。

---

## 5. result packet（要約）

- status: done（判断・設計文書を作成）
- 判断結果: **見送り推奨**（Edit時点で3条件を判定できず誤検知多発・朝会と既存リマインドで代替可能）
- changed_paths: 本ファイル（`references/子04-立案強制hook判断.md`）のみ
- remaining_risks:
  - guard-plan-bucket-mvの説明書（pre-tool-use配下.md/AGENTS）が「登録未適用」の古い前提のまま＝settings.json実態（登録済み）と矛盾。hooks-registry正本整合として別途人間確認が必要（本子は禁止範囲で未修正）。
  - 見送りにより、無人/headless/subagentが計画外で多ファイルを書き換える事故の機械的な最終防波堤は無いまま。子03の朝会は人が起動する日次ゲートで、完全な無人経路はカバーしない（この経路の暴走対策が要るなら別途headless側で検討）。
- 人間ゲート待ち事項: **なし**（見送り推奨のため。実装に転じる場合のみ §4.3 のhook登録承認が必要）。
