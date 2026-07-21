出所評価: 03-harnessとゴールコマンド-評価01.md ／ ラウンド: 01 ／ 宛先: 子03実装担当（codex・task/pf03）

# 修正01: harness・エージェント・ゴールコマンド

※ 修正はすべてworktree（task/pf03）内で行い、パス指定でcommitする。

## 修正項目

### 1. schema検証を契約どおりに

- 対象: `agents-registry/harness/manifest.py` とテスト
- 今の状態: schemaは `additionalProperties: false` なのに、validate_manifest／validate_result が未知プロパティを受理する。
- 期待する状態: run-manifest・result-packetともschema契約（必須・型・pattern・enum・追加属性拒否）どおり不正データを拒否する。
- 修正方法: schemaと同等の検証を実装（schemaファイルを読み込んで照合してよい）し、未知フィールド拒否・型違反のテストを追加。
- やらないこと: schema契約を緩める変更。

### 2. Claude reviewerの評価本文経路を成立させる

- 対象: `harness/runtimes/claude.py`・`delegate.py`・`program_run.py`
- 今の状態: `Operations.review` はClaude delegate後に `*-review-final.md` を要求するが、誰もそのファイルへ保存しないため実行時に評価本文なしでFAILする。
- 期待する状態: Claude/Codexどちらのreviewerでも評価本文を取得でき、delegate→result→review→apply-evaluationが実経路（実planctl・実ファイル）で通る合成テストがある。
- 修正方法: 確認済みの出力形式（--print / --output-format）で最終本文を当該ファイルへ保存するか、review処理をadapterの出力契約に合わせる。fake CLIプロセス（スクリプトで代替）を使い実経路の合成テストを追加（実Claude/Codexは起動しない）。
- やらないこと: 未確認のClaude CLIフラグ・権限回避フラグの推測追加。

### 3. resumeを公開契約にする

- 対象: `harness/delegate.py`・`program_run.py`・run-manifest（thread記録の置き方はstate側。schemaを変える場合は追加属性でなく明示フィールドとして施策1と整合させる）
- 今の状態: `Operations.resume()` が常に「未実装」停止し、FAIL時の同一thread差し戻し（上限2）が実運用で成立しない。
- 期待する状態: Codexは確認済みの `codex exec resume <SESSION_ID> [PROMPT]` 契約（本repoで実運用済み・`--last` 禁止）でresumeでき、thread識別子がmanifest state（gitignore側）に記録され、上限超過で停止する。Claude resumeは未確認のためfeature-disabledのまま。
- 修正方法: codex adapterへresume実装＋fakeプロセスでの実経路テスト（resume成功・上限2超過停止）。
- やらないこと: `--last` の使用・Claude resumeの推測実装。

### 4. worktreeライフサイクルの実git検証

- 対象: `harness/tests/`（新テスト）
- 今の状態: merge --no-ff・smoke・cleanup・conflict停止・一括保持がFakeOperationsのみで、実git検証が無い。
- 期待する状態: 一時git repo＋実worktreeで「明示base作成→実装commit→merge --no-ff→smoke→cleanup」「merge conflictで自動解決せず停止・worktree保持」「一括レビュー待ち子のworktree保持」「main/master非変更」を検証するテストがある。
- 修正方法: tempfile上の合成repoで実git操作を行う隔離テストを追加。
- やらないこと: conflictの自動解決。実リポジトリ（~/Private）への接触。

### 5. 承認セットの同期と統合評価の出力

- 対象: `harness/program_run.py` とテスト
- 今の状態: `_approval()` が書く `承認セット.md` が未追跡で残り、次Waveのdelegateがdirty checkout停止する（完走不能）。完走出力が承認セットpathのみで統合評価の集約が無い。
- 期待する状態: 承認セットを明示パスで同期（`git add -A` 禁止・対象path限定）し、危険操作あり＋複数Waveの合成programが完走する。完走出力に統合評価（子ごとの評価結果集約）と承認セットが揃う。
- 修正方法: 承認セットpathをcommit_sync対象へ明示追加＋回帰テスト（複数Wave・危険操作あり）。
- やらないこと: 承認セット内の危険操作を実行する変更。

### 6.（任意・非ブロッキング）changed_pathsのallowed-path照合

- 評価01追加指摘のとおり、result packetの `changed_paths` を `--allowed-path` と照合し、範囲外変更をFAIL扱いにする検査を入れられるなら入れる（過剰実装はしない）。

## 完了時

- `python3 -m unittest discover -s personal-os/AIエージェント基盤/agents-registry/harness/tests` 全緑＋roles検査PASSを確認し、論理単位でcommit。
- 最終メッセージに「## 実装結果」（状態／最終commit／変更ファイル／テスト結果／resume契約の実装状況）を返す。
