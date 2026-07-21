出所評価: 03-harnessとゴールコマンド-評価02.md ／ ラウンド: 02（フル上限=2の最終ラウンド） ／ 宛先: 子03実装担当（codex・task/pf03）

# 修正02: harness・エージェント・ゴールコマンド

※ 修正はすべてworktree（task/pf03）内で行い、パス指定でcommitする。このラウンドで全PASSにならなければ人間へエスカレーションされる。残る問題は2系統のみ。

## 修正項目

### 1. Operations.review() の判定を評価内容ベースへ

- 対象: `agents-registry/harness/program_run.py`（Operations.review）
- 今の状態: 評価MDファイルが存在すれば内容を判定せず常に `Review(True, ...)` を返す。評価本文が「FAILあり」でも `apply-evaluation` へ進んでしまう。
- 期待する状態: 評価MD本文から機械判定可能な総合判定（例:「総合判定」行の `全PASS` ／ `FAILあり`。項目行の `[FAIL]` 存在も補助判定に使ってよい）を読み取り、全PASSの時だけ `Review(True)`。FAILまたは判定不能（総合判定行が無い等）は必ず `Review(False, reason=...)` とし、applyへ進めない。
- 修正方法: 評価MDのパース関数を追加し、PASS/FAIL/判定不能の3系統をテスト（判定不能はFAIL扱い）。
- やらないこと: 評価本文の自動書き換え・自動PASS化。reviewer prompt側での回避。

### 2. resumeの実経路テスト

- 対象: `agents-registry/harness/tests/`（新テスト）・必要なら `delegate.py` の最小修正
- 今の状態: Codex resume実装はあるが、テストが `runner=` インメモリ注入のみで、`ProgramRunner → Operations.resume → delegate.resume → subprocess` の実経路（PATH上のfake codex CLI実行）を通していない。
- 期待する状態: 一時git repo＋PATH上のfake `codex` 実行ファイルで、(a) 初回review FAIL → resume → PASS → その後にだけapplyされる、(b) 記録済みthread IDがresumeコマンドに使われ `--last` を使わない、(c) 3連続FAILでresumeが上限2回で停止し、worktreeと再開用state（thread state含む）が保持される、の3ケースを実subprocess経路で検証する。
- 修正方法: fake codex CLIスクリプト（呼び出し回数で応答を変える）をfixtureに置き、subprocess経由の統合テストを追加。
- やらないこと: 実際のcodex/claude CLIの起動。`--last` の使用。resume上限の変更。

## 完了時

- `python3 -m unittest discover -s personal-os/AIエージェント基盤/agents-registry/harness/tests` 全緑＋roles検査PASSを確認し、論理単位でcommit。
- 最終メッセージに「## 実装結果」（状態／最終commit／変更ファイル／テスト結果）を返す。
