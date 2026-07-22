# guard-plan-gate — 計画なし実装への「警告のみ」ゲート（段階1）

`PreToolUse` の `Edit` / `Write` / `MultiEdit` を受け、計画に紐づかないコード実装らしき時だけ
1セッション1回、助言の警告を注入する。**deny も ask もしない・exit0＝非ブロッキング**。
program「計画立案システム刷新」子04 §3.2 の設計（見送りではなく段階1採用＝2026-07-22人間判断）。

## 何をするか

`should_warn` が次を**免除**し、残った時だけ `hookSpecificOutput.additionalContext` に警告文を返す。

1. 文書/計画系path → 免除: `.md`、または path に `plans/` `references/` `評価/` `scratchpad` を含む。
2. 対象repoに active計画がある → 免除: cwd（無ければfile_pathの親）から `.git` を辿ってrepo rootを求め、
   その配下 `plans/active/`（浅いglob・最大 `*/*/*/*/plans/active`）に子フォルダが1件でもあれば立案済みと見なす。
   → 親計画から派遣されたsubagentも、親repoにactive計画があるためほぼこの免除に入る。
3. 1セッション1回だけ: `session_id` 単位のマーカー（temp）で2回目以降は黙る（警告スパム防止）。

免除の根拠と限界（子04 §2.2）: Edit時点では「サクッと3条件」を機械判定できず、
active計画の一意解決も原理的に困難。よって**弱い信号で warn-only** に留め、deny から始めない。
誤検知の安全側は「警告しない」（免除を広めに）で、明確な「計画ゼロのrepoでのコード変更」だけ拾う。

## 登録状態（重要）

- **未登録**。この `.py` は settings.json / codex hooks.json に**登録されていない**ため、本体セッションに一切作用しない。
- hook登録は GLOBAL_AGENTS.md §7 の人間ゲート。登録する場合の最小手順（人間承認後）:
  1. `~/.claude/settings.json` の `PreToolUse` に matcher `^(Edit|Write|MultiEdit)$` で
     `.../events/pre-tool-use/guard-plan-gate.py --runtime claude` を追加（既存 `guard-plan-bucket-move` と同形式）。
  2. Codexは `hooks-registry/codex/hooks.json` に対応エントリを足し、人間が `/hooks` で再trust。
  3. `shared/session-board/registered.sh` で登録を確認。
- 段階を上げる（段階2=`ask`・段階3=ファイル計数閾値）のは、段階1の誤検知率を実測してから。deny からは始めない。

## 検証

登録前に単体で確認済み（2026-07-22）: .git+active計画あり→免除／active計画なし→警告1回／
同session2回目→抑制／別session→再警告／`.md`・`scratchpad`→免除／異常入力→exit0無出力。
`CLAUDE.md` はこのファイルへの相対symlink。
