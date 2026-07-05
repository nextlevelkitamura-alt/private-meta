分類: 横断 ／ 種別: 新規作成 ／ 優先: ○

# Codex session-board接続（検証保留）

## 目的

session-board を Codex にも接続し、Codexセッションを当日ボードに 🟢/⏸/🔵 で並べる。

## 現状（2026-07-05・保留）

- **実装は完成し commit/push済み**：`hooks/session-board/codex/` 受け口5本（session-start / prompt-register / session-end / subagent＝Subで🔵自動）＋`hooks.json` 雛形。一時ボードでスモークテスト8/8。
- **登録も完了**：`~/.codex/hooks.json` に設置済み（受け口5本 exists＋exec可を実測）。
- **保留の理由**：実Codexでの検証が **Codex側のモデル空エラー**（`"The '' model is not supported when using Codex with a ChatGPT account."`）でブロック中。
  これは our hooks/board とは無関係の Codexアプリ/モデル選択の問題（`~/.codex/config.toml` は `model = "gpt-5.5"` で無傷・`[hooks.state]` は空＝trust未了だが今回のエラーとは別）。
- 心当たり：`~/.codex/model.json` がローカル `qwen3-4b` 1個のみ（ローカルモデル実験の名残）。モデル解決を邪魔している可能性＝要切り分け。

## 方針（再開条件）

1. **Codex復活**：Macでモデルに `gpt-5.5` を選択／Codexアプリ（`naonomac.local` app-server）を再起動。または `model.json` を退避して切り分け。
2. **trust**：Codexで `/hooks` → 5フックを trust（人間ゲート・約10秒）。`[hooks.state]` に5行入る（Claudeが検算可）。
3. **検証**：trust済みの新規セッションで普通のプロンプトを1つ → Claude がボードmdを直読みして判定。

## 完了条件（レビュー項目）

実Codexで各1回実測：(1)開始で🟢登録 (2)Stopで⏸ (3)サブで🔵自動 (4)⏸→🟢復帰 (5)subagent/headless(`AIJOBS_RUN`)は非登録。
実装側の詳細・設計は master 計画（`../active/2026-07-04-セッション宣言型ボードとplans規約/plan.md` の2026-07-05追記）と `AIエージェント基盤/hooks/references/codex-hooks.md`（実務マニュアル）を参照（本節に重複させない）。
