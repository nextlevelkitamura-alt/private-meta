親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善

# Stopレビュー差し戻しゲート
## 目的

ライト以上の実装完了を`SubagentStop`と通常`Stop`で捕捉し、別のCodexレビュー担当が正本plan.mdの全レビュー項目を
採点するまで完了させない。FAILなら、根拠を失わない具体的な修正計画MDを生成し、実装担当へ戻す。

## 現状

- role-promptsには実装→レビュー→FAIL差し戻しの契約があるが、Hookはsession-board状態更新だけで品質ゲートを持たない。
- watch.shにはDONE→レビュー配布ロジックがあるが、Orca状態Hookの実機成立が未確認で、一般のsubagentにも適用されない。
- 現行のレビュー結果はチェック追記か大きい指摘だけ別ファイルで、毎回の採点・修正ラウンドを追跡できない。
- Stopは各ターンで発火するため、単純に「Stop時はレビュー」では途中報告や質問まで誤ってレビューへ送る。

## 方針

### 1. 状態機械

```text
implementing
  └─ IMPLEMENTATION_READY
       → review_pending
          → review_running
             ├─ PASS → reviewed_pass
             ├─ FAIL → revision_pending → implementing → review_pending
             └─ BLOCKED/PLAN_DEFECT → human_gate
```

- Hookは明示マーカーとgate状態を使い、通常の途中Stopではレビューを起動しない。
- ライトは差し戻し1回、フルは2回。上限超過は人間ゲート。
- 同じ実装commit＋plan SHAへのレビューを冪等にし、重複Codex起動を防ぐ。

### 2. SubagentStop

実装サブエージェント停止時に次を検査する。

- 変更一覧、commit hash、テスト結果、未解決リスク、判断メモ、`IMPLEMENTATION_READY`。
- plan読込証明と現在SHAの一致。
- git差分が許可範囲内か、未コミット変更がないか。

揃えば`review_pending`を作り親へ返す。欠けていれば1回だけblockし、欠落項目を具体的に再提出させる。
サブエージェント自身にはCodexレビューを起動させず、親／指揮官が別threadのreviewerを配布する。

### 3. 通常Stop

- メインが実装担当の場合も同じ`IMPLEMENTATION_READY`契約を検査する。
- `review_pending`または`revision_pending`が残る間は、セッション完了をblockする。
- ClaudeはadditionalContext、Codexは`decision:block`のreason継続プロンプトで次動作を返す。
- Hook内部から長時間の`codex exec`を同期実行しない。Hookは要求生成・完了拒否まで、実レビューはOrca／明示subagentへ委譲。

### 4. Codexレビュー担当

- 実装担当と別thread／agent ID。read-only。編集・修正・pushを禁止。
- 入力はplan絶対パス＋SHA、base/target commit、実装報告、レビューラウンド。
- plan本文をプロンプトへ複製せず、必ずファイルを直接読む。
- 完了条件の各項目を`PASS=1 / FAIL=0 / BLOCKED`で採点し、全項目に根拠を付ける。
- 追加で、範囲外差分、未実行検証の虚偽、失敗ログ省略、regression、secret、戻し方を確認。
- 必須項目FAILまたはP0/P1相当の問題があれば、合計点に関係なく最終FAIL。
- レビュー項目自体が曖昧・検証不能なら`PLAN_DEFECT`とし、実装者へ推測修正させず人間／計画オーナーへ戻す。

### 5. 評価MD

`reviews/NN-review.md`は次を必須とする。

```text
対象plan / plan SHA / diff範囲 / reviewer識別子 / 実行日時
項目別採点:
  R1 PASS 1/1 — 根拠: path:line / test
  R2 FAIL 0/1 — 期待 / 実際 / 再現
横断確認
総合: X/Y
判定: PASS | FAIL | BLOCKED | PLAN_DEFECT
```

「問題ありません」「だいたいOK」のように項目別根拠が無い評価はSubagentStopで拒否する。

### 6. 修正計画MD

FAIL時は`revisions/NN-fix-plan.md`を評価MDから決定的に生成する。

- 各FAIL項目の原文、根拠、期待状態、再現／検証コマンド。
- **残す成果**と**直す対象**を分ける。
- 触ってよい範囲／触らない範囲、既存契約、新しい完了マーカー。
- 再評価で見る項目。元のPASS項目を壊していない回帰確認。
- 汎用的な「レビュー指摘を直す」だけの生成をlintでFAILにする。

実装担当へは元plan＋最新fix-planの2パスを渡す。元planを書き換えて失敗履歴を消さない。

### 7. サクッと例外と障害時

- サクッとはCodexレビューを起動せず、自己確認＋diff要約で完了できる。
- ライト以上でCodexを起動できない、trust切れ、上限到達、reviewer異常終了なら完了をPASS扱いしない。
- `review_pending`のまま人間に「未レビュー」と見える状態で止め、代替モデルへの変更は人間ゲート。

## 完了条件（レビュー項目）

- [ ] 実装SubagentStopが薄い完了報告を1回だけblockし、必要項目を具体的に再要求する
- [ ] 通常Stopがライト以上の`review_pending`／`revision_pending`を残したまま完了させない
- [ ] Codex reviewerが別thread・read-onlyで、全レビュー項目を採点し根拠付き評価MDを生成する
- [ ] FAIL評価から、残す成果・直す対象・期待状態・再検証を持つ修正計画MDが生成される
- [ ] 修正担当が元plan＋最新fix-planを読み、再実装後に次ラウンドの独立レビューへ戻る
- [ ] ライト1回／フル2回の差し戻し上限と、人間介入への遷移がテストされている
- [ ] PASS・FAIL・BLOCKED・PLAN_DEFECT・Codex起動不能の5経路で、誤って完了扱いしない
- [ ] サクッと修正はレビュー成果物なしで自己確認＋diff要約により完了できる
