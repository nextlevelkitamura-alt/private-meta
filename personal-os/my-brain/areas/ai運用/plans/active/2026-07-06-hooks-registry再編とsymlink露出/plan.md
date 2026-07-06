分類: 横断（AIエージェント基盤 / hook） ／ 種別: 構造再編 ／ 形態: plan（単発） ／ 優先: ○ ／ 規模: ライト〜フル

# hooks-registry 再編と symlink 露出

## 継続メモ（会話圧縮・再開用）

この plan.md 単体で再開できるよう要点を固定する。

- 状態: **実装＋独立レビュー完了（Sonnet5・9/9 PASS・2026-07-06）**。バケット active/。残: **Codex 再 trust＋実Codex実測**（人間の /hooks）。
- 起点: この plan.md が正本。表示用 HTML は派生物（都度 `/html` 再生成・正本にしない）。
- 決定は「## 方針」「## 決定ログ」に固定。未確定は「## 決定ログ / 未確定」。
- 次アクション: ①この差分をコミット（範囲＝hooks-registry＋doc＋本plan・push は別ゲート）→ ②Codex で `/hooks` 再 trust → ③実Codexで 開始🟢/Stop⏸/サブ🔵 を実測 → 全 OK で done/。
- 触る実体: repo `AIエージェント基盤/hooks/`（改名対象）、runtime `~/.claude/settings.json`・`~/.codex/hooks.json`（symlink 化・Codex 再 trust）。
- 不変: `GLOBAL_AGENTS.md` の既存 symlink、歴史記録（過去デイリー・plans/done・日付き research）。

## 実装結果（2026-07-06・実装＋レビュー完了）

移行手順 1〜9 を実行済み。要点:

- `hooks/` → `hooks-registry/`。共有本体 `hooks/session-board/`（＋新 `common.py`）／受け口箱 `claude/`・`codex/`。
- 受け口は `realpath` 自己解決の薄いシム＋`common.py` 集約（重複排除）。runtime差＝SessionStart出力(plain/JSON)・Codex専用subagent・Claude専用milestoneのみ。
- 窓: `~/.claude/agent-hooks → claude/`・`~/.codex/agent-hooks → codex/`・`~/.codex/hooks.json → codex/session-board/hooks.json`。`settings.json` は窓パスへ（runtime設定はバックアップ）。
- 生きた旧パス参照を一掃（`GLOBAL_AGENTS.md`・`loop-types.md`・各 AGENTS.md・基盤入口一覧）。歴史（plans/・日付きresearch）は不変。
- 検証: 窓越し realpath 貫通・一時ボードで全状態遷移・9py構文・pyc追跡外 すべて PASS。
- **独立レビュー（Sonnet5・read-only・spawn無し）: 総合 PASS（9/9）**。軽微3件（registered.sh の trust確認補助→対応済／サブ🔵の実Codex実測残／scratchpad一時物）。
- 残（人間）: **Codex `/hooks` 再 trust → 実Codexで実測 → done/ へ**。

## 目的

`hooks/` を、他の基盤フォルダ（`loops-registry` / `global-skill-registry` / `repo-registry`）と揃った **`hooks-registry/`** に作り替える。**runtime 別（claude / codex）の受け口を top の「箱」に集約**し、機構の共有部は `hooks/` にまとめる。正本は repo・各 runtime へは **symlink（窓）で露出**する型に統一する。将来フックが増えても「箱に受け口を足す」で済む形にする。

狙いは3つ。

1. **命名の一貫性**: `loops-registry/loops/` と揃う `hooks-registry/`。
2. **露出の一貫性**: `GLOBAL_AGENTS.md` と同じ「正本 repo・runtime は symlink」で hook も露出する。
3. **重複の排除**: Claude/Codex 受け口の写し（最大8割同一）を共有ロジックに寄せ、runtime 差（入出力・片側専用）だけ各受け口に残す。

## 現状（2026-07-06）

- 置き場: `personal-os/AIエージェント基盤/hooks/`。中身は `session-board/`（唯一の稼働フック）・`references/`・`research/`・`AGENTS.md`・`CLAUDE.md`。
- session-board 内部: 直下に共有（`board.py`＋手順md＋`daily-template.md`＋`README.md`）、`claude/`（受け口3本＋`milestone.md`）、`codex/`（受け口3本＋`subagent.py`＋`hooks.json`）。
- 登録は **絶対パス直書き**（symlink ではない）。`~/.claude/settings.json`（command×3＋prompt×1）／`~/.codex/hooks.json`（command×5・trust 済み・repo 雛形とは別実体のコピー）。
- global 運用ルールは `GLOBAL_AGENTS.md` が正本で、`~/.claude/CLAUDE.md`・`~/.codex/AGENTS.md`・`~/.config/opencode/AGENTS.md` へ **symlink 済み**（この型を hook にも使う）。
- 受け口の重複実測: `prompt-register.py` 約8割・`session-end.py` 約6割・`session-start.py` 約5割が同一。差は runtime の I/O 契約（入力フィールド・文脈の出し方）と登録/trust のみ。ロジックは同一。
- 旧パス `hooks/session-board` を指す外部参照: 約7ファイル（loop-types.md・各 AGENTS.md・references・registered.sh 等）。

## 方針（決定事項）

- **A: top を `hooks/` → `hooks-registry/` に改名**（`-registry` 系の兄弟と統一）。
- **runtime 別の受け口を top の箱に集約**: `hooks-registry/claude/` と `hooks-registry/codex/` を `hooks/` と**同階層**に置く。各箱は「その runtime の受け口を全機構ぶん入れる箱」（＝他の種類のフックが増えてもここに足す）。
- **機構の共有部は `hooks-registry/hooks/<機構>/`**（本体 `board.py`＋手順md＋`common.py`＋機構ルール）。runtime 非依存。
- 受け口は **入出力の差だけ持つ薄いシム**にし、共有ロジックは `common.py` に集約（重複排除）。`milestone.md`（Claude prompt型）・`subagent.py`（Codex）は**片側専用**なので統合しない。
- **登録は symlink 露出**。runtime の設定は「安定パス（symlink）」を指し、実体は repo。
- **ルールは二重管理しない**: global 運用ルールは `GLOBAL_AGENTS.md`（既存 symlink）のまま、hook 側にコピーしない。hook 固有ルールだけ配下に置く。
- **実装は本計画確定後の別ステップ**。本計画は構造と手順の確定まで。

## 目標フォルダ構造

```
personal-os/AIエージェント基盤/
└── hooks-registry/                    ← 旧 hooks/（改名）
    ├── hooks/                         ← 各機構の「共有・runtime非依存」部
    │   └── session-board/
    │       ├── board.py                 本体エンジン
    │       ├── common.py               受け口の共通ロジック（新規・重複排除）
    │       ├── session-start.md  session-end.md  daily-template.md
    │       ├── registered.sh
    │       └── AGENTS.md / CLAUDE.md    session-board のルール（hook固有）
    ├── claude/                        ← Claude 受け口の箱（全機構ぶん）
    │   └── session-board/
    │       ├── session-start.py  prompt-register.py  session-end.py   薄いシム（common を呼ぶ）
    │       ├── milestone.md ★           prompt型（Claudeだけ）
    │       └── AGENTS.md / CLAUDE.md
    ├── codex/                         ← Codex 受け口の箱（全機構ぶん）
    │   └── session-board/
    │       ├── session-start.py  prompt-register.py  session-end.py
    │       ├── subagent.py ★            Codexだけ
    │       ├── hooks.json               Codex 登録の正本（symlink元）
    │       └── AGENTS.md / CLAUDE.md
    ├── references/                    ← 既存（claude-hooks.md 等）
    ├── research/                      ← 既存
    └── AGENTS.md / CLAUDE.md
```

補足:

- 受け口（`claude/session-board/*.py`）は、共有本体（`hooks/session-board/board.py`・`common.py`）を相対 import で呼ぶ（`../../hooks/session-board/`）。この相対参照は移行時に必ず通す。
- 手順md（`session-start.md` 等の「読む指示」）は runtime 共通。`hooks/session-board/` に1つだけ置き、両受け口が参照する。
- 将来の別フックは `hooks/<新機構>/`（共有）＋ `claude/<新機構>/`・`codex/<新機構>/`（受け口）を足す。

## 登録と symlink（.claude / .codex の露出）

正本は repo、runtime 側には「窓（symlink）」と「適用済みの設定」だけを残す。

- **スクリプトの露出**: `~/.claude/agent-hooks → hooks-registry/claude/`、`~/.codex/agent-hooks → hooks-registry/codex/` の symlink を張る。設定内のパスは `~/.claude/agent-hooks/session-board/session-start.py` のような**安定パス**にする（runtime 箱を丸ごと窓にするので、機構が増えても窓は1本のまま）。
- **Claude 登録**: `~/.claude/settings.json` は hooks 以外の設定も持つため丸ごと symlink 不可。hooks ブロックのパスを agent-hooks 経由に更新（保存で自動反映・trust 不要）。
- **Codex 登録**: `~/.codex/hooks.json` を repo 正本 `hooks-registry/codex/session-board/hooks.json` への **symlink** にする（repo が正本・1本）。※ session-board が唯一の Codex フックである前提。他ツールが Codex フックを足す運用に変わったら merge 方式へ切替。
- **Codex 再 trust**: パス・内容が変わるので `/hooks` で再 trust（trust は hash/パスに紐づく）。
- **手動確認**: `ls -la <path>`（矢印 `->`＋先頭 `l` が symlink）／`readlink -f <path>`（最終実体）／実ファイルは矢印なし・先頭 `-`。

## ルールの置き場（二重管理しない）

- **global 運用ルール**（Claude/Codex の動き方の共通）→ `GLOBAL_AGENTS.md` が正本・既に各 runtime へ symlink 済み。**hook 側にコピーしない**。
- **hook 固有ルール**（session-board の使い方・状態の意味・登録手順）→ `hooks/session-board/AGENTS.md`（＋ `claude/session-board/AGENTS.md`・`codex/session-board/AGENTS.md`）。

## 移行手順

1. **改名**: `git mv hooks hooks-registry`。
2. **箱を作る**: `hooks-registry/hooks/`・`hooks-registry/claude/`・`hooks-registry/codex/` を用意。
3. **中身を移す**: 共有（board.py・手順md・common候補・registered.sh・機構AGENTS）→ `hooks/session-board/`。Claude 受け口（現 `session-board/claude/*`）→ `claude/session-board/`。Codex 受け口 → `codex/session-board/`。すべて `git mv`。
4. **共通コア抽出**（任意・同時推奨）: 受け口の共通部を `hooks/session-board/common.py` に出し、`claude/…`・`codex/…` を薄いシムに。
5. **内部相対参照の修正**: 受け口 → 共有本体・手順md の相対パス（`../../hooks/session-board/…`）を通す。
6. **symlink 作成**: `~/.claude/agent-hooks → …/claude/`、`~/.codex/hooks.json → …/codex/session-board/hooks.json`。
7. **登録更新 ＋ Codex 再 trust**: `~/.claude/settings.json`・`~/.codex/hooks.json`（symlink 化）のパスを窓経由へ。repo 雛形・`registered.sh` も更新 → `/hooks` 再 trust。
8. **外部参照の更新**: `hooks/session-board` → 新パスを repo 全体で更新（約7ファイル。grep で洗い出す。歴史記録は不変）。基盤入口 `AIエージェント基盤/AGENTS.md` の「フォルダ」一覧も `hooks` → `hooks-registry`。
9. **実測 → doc 更新 → コミット**: 開始🟢 / Stop⏸ を Claude・Codex 各1回。`hooks-registry/AGENTS.md`・`references` 等を新構造に。まとめて1コミット（push は人間ゲート）。

## 実装後レビュー（サブエージェント評価）

実装が終わったら、**read-only のサブエージェントに独立評価を依頼**する。委譲の連鎖を避けるため、エージェントには「**自分で読んで判定し、他エージェントを spawn しない**」と明示する（過去に委譲カスケードで空振りした実績あり）。

評価項目（各 PASS/FAIL＋根拠パス・行 で返させる）:

- [ ] 構造が本計画の目標フォルダと一致（`hooks-registry/{hooks,claude,codex}/session-board/`）。
- [ ] symlink が正しく実体を指す（`ls -la` の矢印・`readlink -f`）。壊れリンク無し。
- [ ] Claude・Codex 双方で 開始🟢 / Stop⏸ の実測ログがある。
- [ ] 旧パス参照（`hooks/session-board`）が生きた doc に残っていない（歴史記録を除く）。
- [ ] 受け口の重複が `common.py` に集約され、runtime 差だけが残っている。
- [ ] global 運用ルール（`GLOBAL_AGENTS.md`）を hook 側にコピーしていない。
- [ ] Codex 再 trust 済み（`/hooks`・`[hooks.state]`）。
- [ ] 非ブロッキング・secret 非出力の規律を満たす。

FAIL は差し戻して修正 → 再評価。全 PASS で done ゲートへ。

## 完了条件（レビュー項目）

- [x] 実体が `hooks-registry/{hooks,claude,codex}/session-board/` に移動し、生きた参照に旧パス `hooks/session-board` が残っていない（歴史記録を除く）。
- [x] `~/.claude`・`~/.codex` の登録が **symlink（agent-hooks／hooks.json）経由**（`ls -la` で矢印確認）。
- [x] **Claude** で 開始🟢 / Stop⏸ 実測 PASS（窓越し・一時ボードで全遷移・独立レビュー確認）。
- [ ] **Codex** で 再 trust 後、開始🟢 / Stop⏸ 実測 PASS（サブ🔵 は可能なら）。★残（人間の /hooks）
- [x] repo 内の旧パス参照（約7）＋基盤入口 AGENTS.md の一覧を更新。
- [x] global 運用ルールを hook 側にコピーしていない（`GLOBAL_AGENTS.md` symlink は不変）。
- [x] 受け口の重複が `common.py` に集約（共通コア抽出を実施した場合）。
- [x] **実装後レビュー（サブエージェント評価）が全 PASS**（Sonnet5・9/9・2026-07-06）。

## コスト・リスク

- **Codex 再 trust 必須**（hash/パス変化）。
- **内部相対参照**（受け口 → 共有本体は別フォルダになるため `../../hooks/session-board/`）と**外部参照約7ファイル**の更新漏れに注意（grep 徹底）。
- top 改名で settings.json / hooks.json のパスも変わる（今回1回は必ず更新／以後の repo 移動は symlink が吸収）。
- 1回きりの移行として良い形に固めてから動かす。

## 決定ログ / 未確定

- 決定（2026-07-06・人間承認）: A（`hooks-registry/` 改名）／ claude・codex を top の箱として `hooks/` と同階層に置く（他種類の受け口も入る箱）／ 機構共有部は `hooks/<機構>/`／ 共通コア抽出／ symlink 露出／ global ルールは二重に置かない／ 実装後にサブエージェント評価を入れる。
- 未確定: (a) 受け口を「1本化（runtime判定1ファイル）」まで踏むか「runtime別の薄いシム」に留めるか → 既定は**薄いシム**（現状に近く安全）。(b) symlink 粒度は **runtime 箱をディレクトリ単位で窓化**（`agent-hooks → …/claude/`）を既定。
- 表示用 HTML: 最終概要を `/html` で都度生成（正本はこの md）。
