分類: 横断 ／ 種別: 統合整理 ／ 形態: program ／ 優先: ○ ／ 規模: フル

# hooks-registry の最終整理

## 目的

Claude/Codexが共通で使うhook本体を `hooks-registry/events/` に1組だけ置き、各イベントを
「機能名.py + 同名.md + AGENTS.md」で即座に理解できる状態にする。Claudeのグローバル登録は
公式どおり `~/.claude/settings.json` を登録表として直接使い、repo側の同期補助 `apply-hooks.py` は置かない。

## アーカイブ判断（2026-07-14）

人間が本programのアーカイブを明示承認した。実装済みの構造・説明書は `hooks-registry/` を恒久正本として残す。
未完だった最終確認は、重複して実行しないよう次の最新計画へ移管する。

- `03 統合検証とruntime確認` の既存5イベントE2EとCodex再trustは、
  `plans/planning/2026-07-13-完了判定とアーカイブ運用/` が全hook変更後に一度だけ行う。
- `05 daily-notion-syncの安全回復` の停止状態・独立レビュー・人間確認前のNotion実書き込み禁止は、
  `plans/active/2026-07-12-loopレジストリTurso移行/plans/04-統合・切替・旧一覧廃止.md` が所有する。

この移管は未完を完了と偽るものではない。以後の実行・評価・人間ゲートは移管先の完了条件で追う。

## 全体像

```text
repo 正本
  events/<イベント>/       実行.py + 同名.md + AGENTS.md
  shared/session-board/    共通エンジン
  claude/                  登録先の説明だけ
  codex/hooks.json         Codex登録の正本
        │
        ├─ ~/.claude/agent-hooks ─┐
        └─ ~/.codex/agent-hooks ──┴─> hooks-registry/ （窓）

Claude: ~/.claude/settings.json が events/ の実行.pyを直接登録
Codex : ~/.codex/hooks.json -> repo/codex/hooks.json
```

## 現状

- 共有イベント本体・`AGENTS.md` / `AGENTS.html`・runtime窓は、前段の再編で作成済み。ただし Claude用の
  `claude/hooks.json` と `apply-hooks.py` は、公式の通常設定にない分割を補う独自同期であり、今回廃止する。
- 旧 `hooks/session-board/` を指す基盤入口など、現在の構成と食い違う説明が残る可能性がある。
- 画像で示された `hooks-registry-structure-proposal.html` は一時表示物であり、正本ではない。恒久の説明は
  各 `AGENTS.md` と同名 `AGENTS.html` に置く。
- 作業ツリーには本件と無関係の未コミット変更がある。対象外を戻さず、対象pathだけを扱う。

## 決定

- **Claudeの登録正本は `~/.claude/settings.json` の `hooks` 項目**とする。settings全体をsymlinkにしない。
- `claude/apply-hooks.py` と `claude/hooks.json` は削除する。repoの `claude/AGENTS.md` は登録先と更新手順を説明するだけにする。
- Python実装は `events/` の1組だけ。`.md` は実行しない説明書であり、変更するAI/人間が読む。
- `README.md` を新設しない。フォルダの入口はすべて `AGENTS.md`、人間向け表示は同名 `AGENTS.html`。
- Codexの `hooks.json` はrepo正本のまま維持し、変更後のtrustは人間が `/hooks` で行う。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [x] 01 Claude登録を直接設定へ戻す … 完了
    並列: 可 ／ レビュー: 都度
    結果: Claudeの5イベント直接登録を確認し、`apply-hooks.py` とClaude専用`hooks.json`を削除した
    場所: plans/01-claude登録簡素化.md ／ 依存: ―
- [x] 02 AGENTS中心の説明を現構成へ揃える … 完了
    並列: 可 ／ レビュー: 都度
    結果: registry内の現行説明・恒久reference・対応HTMLを更新した。registry外の旧参照は03で統合する
    場所: plans/02-説明と表示の整合化.md ／ 依存: ―
- [ ] 03 統合検証とruntime確認 … 人間確認（後続計画へ移管）
    並列: 不可 ／ レビュー: 都度
    結果: hooks本体・runtime窓・既存E2EはPASS。Codex再trustを含む最終runtime確認は、全hook変更後に後続計画で一度だけ行う
    場所: plans/03-統合検証とruntime確認.md ／ 依存: 01, 02
- [x] 04 独立レビューと完了判定 … 完了
    並列: 不可 ／ レビュー: 都度
    結果: hooks再編は条件付き合格。Notion同期P0、Codex再trust、launchd実機確認を未完として返した
    場所: plans/04-独立レビューと完了判定.md ／ 依存: 03
- [ ] 05 daily-notion-sync の安全回復 … 実装（後続計画へ移管）
    並列: 不可 ／ レビュー: 都度
    結果: v3解析・fail-closed・stubテスト13件PASS、launchd停止を確認。独立レビューと人間確認前の実機復帰は7/12計画へ移管
    場所: plans/05-daily-notion-sync安全回復.md ／ 依存: 03, 04

## 実行順

01と02は別ファイル群を主に扱うため並列に実行できる。ただし02は01の「apply廃止」という決定を前提に
記述する。03は両方の結果を統合してから、04は03の検証証拠がそろってから開始する。

## 人間ゲート

- 01の `apply-hooks.py` / `claude/hooks.json` 削除と、`~/.claude/settings.json` のhooks直接更新は、
  2026-07-14の人間承認済み。
- Codexの `/hooks` 再trustと、実Codexでの発火確認は人間操作が必要。AIはtrust状態を書き換えない。
- daily-notion-syncは現行v3行を旧形式として解析し、既存Notion行をarchiveし得る。launchdを安全に止めるか、
  v3解析とテスト契約を直すかは、別の緊急子計画として人間が選ぶ。修正・Notion実行はこの計画に含めない。
- 05の停止、実装、stub検証は2026-07-14に人間承認済み。Notion APIへの実書き込み、launchd再登録・復帰、
  Codexの再trustは、各検証結果を示した後の人間確認が必要。
- commit、push、既存の一時proposal HTML削除は、この計画の権限に含めない。

## 完了条件（レビュー項目）

- [ ] `hooks-registry/claude/` に `apply-hooks.py` とClaude専用 `hooks.json` がなく、`claude/AGENTS.md` が
  `~/.claude/settings.json` を登録先として正しく示す。
- [ ] `~/.claude/settings.json` の5イベントが `~/.claude/agent-hooks/events/` の共通実行本体を指し、
  settings全体はsymlinkではない。
- [ ] `events/` の4イベントすべてで、実行 `.py` と同名 `.md`、および `AGENTS.md` / `CLAUDE.md` が存在する。
- [ ] `AIエージェント基盤/AGENTS.md`、`GLOBAL_AGENTS.md`、`hooks-registry/` の現行説明、稼働中loop・Skill、恒久referencesに、
  廃止済みの構造・README・`apply-hooks.py` が現行仕様として残らない。日付付きresearchは歴史として変更しない。
- [ ] `AGENTS.html` は対応するmdの人間向け派生物で、白背景・外部依存なし・正本を置換しない。
- [ ] シムE2E、ボードE2E、個別Pythonテスト、JSON検証、symlink診断、`git diff --check` がすべてPASSする。
- [ ] Codexの `/hooks` 再trustと開始/Stopの実機確認の結果が、人間操作として記録される。
- [ ] 独立read-onlyレビューが対象範囲の差分・検証・残リスクを評価し、全PASSと判定する。
- [ ] daily-notion-syncは修正完了までlaunchdから安全に停止され、v3 session-board行の解析・archive保護・
  stub検証を独立レビューでPASSする。Notionへの実書き込みは人間確認後だけにする。

## 引き継ぎ共通事項

- 最初に読む順番: `AIエージェント基盤/AGENTS.md` → `hooks-registry/AGENTS.md` → この `program.md` → 担当子計画。
- 許可path: `personal-os/AIエージェント基盤/hooks-registry/`、必要最小限の基盤入口・references、
  および `~/.claude/settings.json`（01のみ）。
- 禁止: secret表示、settings全体のsymlink化、Codex trust設定の直接編集、対象外変更の巻き戻し、push。
- 添付スクリーンショット: 会話添付の `codex-clipboard-16240eb1-1465-41a5-af76-311472c2f7f1.png`。
  見る点は「古いproposalがREADME/apply前提であり、今回の恒久説明とは異なる」こと。

## 既往の経緯

2026-07-06のregistry化、2026-07-14の共通events化までの詳細は旧 `plan.md` に記録されていた。
このprogramはその計画を再開し、今回の「Claude登録を直接設定へ戻す」決定を最終段として扱う。過去の
日付付きresearchと実装履歴は改変しない。
