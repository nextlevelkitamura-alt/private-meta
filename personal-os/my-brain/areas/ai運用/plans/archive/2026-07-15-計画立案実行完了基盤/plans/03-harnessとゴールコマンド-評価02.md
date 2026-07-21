対象計画: 03-harnessとゴールコマンド.md ／ ラウンド: 02  
diff範囲: `8d7fc3a..fb1e12f`（修正diff: `fec91a9..fb1e12f`） ／ 評価者: read-only reviewer

# 評価02: harness・エージェント・ゴールコマンド

## 修正01の項目別対応確認

1. [PASS] schema検証  
   `manifest.py` がschemaファイルを読み込み、`additionalProperties: false`、型、enum、pattern等を検証する。独立実測で、manifest/result双方の未知プロパティと型不正をすべて拒否した。

2. [PASS] Claude reviewerの評価本文経路  
   Claude adapterのJSON出力から`result`本文を`<task>-final.md`へ保存し、`Operations.review()`が評価MDへ転記する経路を実装。fake Claude CLIを使う実git lifecycleテストが完走し、Claude経路が評価本文を要求することを確認した。

3. [FAIL] resumeの実経路検証  
   Codex resume実装自体はある。thread stateを保存し、`codex exec resume <SESSION_ID> <PROMPT>`を組み立て、`--last`を使わないことは単体テストで確認できる。  
   ただし、修正指示が要求した「fake CLIプロセスを使う実経路」のresumeテストはない。該当テストは`runner=`へのインメモリ関数注入であり、`subprocess.run`、fake `codex` executable、`ProgramRunner → Operations.resume → delegate.resume`の一連を通していない。

4. [PASS] 実git worktree lifecycle検証  
   一時git repo＋fake runtime CLIで、実worktree作成、worker commit、`merge --no-ff`、smoke、cleanup、main非変更を検証している。別テストで実merge conflict時の自動非解決・worktree保持、および一括レビュー待ち中のworktree保持も確認している。

5. [PASS] 承認セット同期と統合評価  
   `sync_approval()`は対象の承認セットpathだけを`git add -- <path>`で同期する。危険操作あり・依存関係による複数Waveの実git合成programが完走し、clean status、承認セット、子ごとの`integration_evaluation`を確認している。

6. [PASS] 任意: `changed_paths`照合  
   実装・resumeともresult packetの変更pathが`allowed_paths`外ならblockedにする回帰テストがある。

## 完了条件の再採点

- [PASS] delegateの明示引数、write taskのbase必須、task-scoped worktree、read-only省略、dirty/scope conflict停止、secret redact、並列2task分離をテストで確認。
- [PASS] Task Packetに必要項目があり、run-manifest/result-packetは未知プロパティ・型不正を拒否することを実測。
- [PASS] roles 3定義とClaude/Codex薄い写像をroles検査で確認。固定worktree・branch・モデルID・Program固有背景なし。
- [PASS] `/codex-impl`は共通delegate契約を示し、実git合成taskでdelegate→result→Claude/Codex reviewer→apply-evaluationが通る。custom-agent-creator参照も更新済み。
- [FAIL] `program-run`のFAIL時resume・全PASS時のみ同期の実経路が未保証。`Operations.review()`は評価本文が存在すれば内容を判定せず常に`Review(True, ...)`を返すため、本文がFAILでもapplyへ進む。FAIL→resumeおよび上限停止は`FakeOperations`だけで再現され、実adapter経路では検証されていない。
- [PASS] 実gitでworktree作成→commit→`merge --no-ff`→smoke→cleanup、bulk待機時の保持、merge conflict停止、main非変更を確認。
- [PASS] delegateが全workerへ`PLAN_RUN_MANIFEST`を渡し、必要なmanifest項目を保持する。
- [PASS] 危険操作を実行せず承認セットへ対象path限定で同期し、複数Wave完走と統合評価出力を確認。
- [PASS] Claudeの`--print`・`--output-format`はローカル`claude --help`で確認。未確認時はfeature-disabled。runtime設定・trust・symlink・codex-consultへの変更なし。`--repo-root`明示でPrivate固有pathの決め打ちなし。

## 検証結果

- `python3 -m unittest discover -s personal-os/AIエージェント基盤/agents-registry/harness/tests`  
  22件PASS
- `bash personal-os/AIエージェント基盤/agents-registry/roles/__tests__/test_role_definitions.sh`  
  PASS
- `git diff --check 8d7fc3a..fb1e12f`  
  PASS
- 変更禁止範囲（`skills/plan-ops/`、`hooks-registry/`、runtime設定、`codex-consult`）への差分なし。

## 総合判定

FAILあり。

### 修正指示ドラフト

1. `Operations.review()`を、評価MDの存在ではなく機械判定可能な評価結果でPASS/FAIL判定する実装へ変更する。FAILまたは判定不能な本文は必ず`Review(False, reason=...)`とし、`apply-evaluation`へ進めない。  
2. 一時git repo＋PATH上のfake `codex` CLIを使い、`ProgramRunner → Operations.resume → delegate.resume → subprocess`の実経路テストを追加する。初回review FAIL、resume後PASSを再現し、記録済みthread ID使用、`--last`不使用、PASS後にだけapplyされることを検証する。  
3. 同じ実経路で3回連続FAILを作り、resumeが2回で停止し、worktreeと再開用stateが保持されることを検証する。