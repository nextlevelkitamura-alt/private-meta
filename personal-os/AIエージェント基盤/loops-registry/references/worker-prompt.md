# worker プロンプトの型（ai-jobs run-card を1枚実行する）

ai-jobs の run-card **1枚**を最後まで実行するワーカー（Orca / Codex / Claude）に渡す標準プロンプトの型。
loop の**起動**側（launchd＋dispatcher＋runner）は `loop-runbook.md`、実行レーンの**契約**（状態＝フォルダ位置・claim=mv・レビューpair・worktree 削除）は `../ai-jobs/AGENTS.md` が正本。ここは重複させず、**ワーカーの手順だけ**を定める。

## 前提（呼び出し側が満たす）

- カードは既に `running/` にある。掴み（ready→running）は**起動側の責務**：dispatcher が起動前に `jobctl.sh claim <card>` する（アトミック＝奪い合い防止）。手動レーンなら人間が claim してからワーカーを起動する。**ワーカーは掴みの調停をしない。**
- ワーカーには「card 名」と「ai-jobs の base 絶対パス」と「plan-ops `jobctl.sh` のパス」が渡る。状態遷移は必ず `jobctl.sh` 経由（素の `mv` は cwd 依存で誤るので使わない）。

## ワーカーの手順

1. **カードを読む**：`<ai-jobs>/running/<card>` を全部読む。`担当 / 出所 / 対象repo / 作業導線 / ブランチ / 依頼 / 許可 / 完了条件 / 差し戻し上限` を把握し、自分の engine が `担当` と一致するか確認する。
2. **導線を読む**：対象repo を触る前に `対象repo/AGENTS.md`（＝`作業導線`）を読む。`完了条件` ＝ `出所`（計画）のレビュー項目なので、必要なら出所も読んで正確に理解する。
3. **worktree で作業する**：`ブランチ` 指定に従い git worktree を作り、**その中で**作業する。対象repo のチェックアウト中ブランチで直接作業しない（レビューと差し戻し修正が同じ worktree を使うため）。
4. **依頼だけをやる**：`依頼` を `許可` の範囲で実装する。ゴールは `完了条件` を満たすことだけ。自己判断で範囲を広げない・**自己申告で「完了」にしない**（完了判定は独立レビューが行う）。
5. **secret を書かない**：token / 認証値 / 環境変数の値を、カード・コード・ログ・報告に出さない。
6. **レビューへ渡す**：完了条件を満たしたら `jobctl.sh review <card>`（running→review）。**worktree は消さない**（レビュー合格＆反映の後に消す＝ai-jobs §4.5）。
7. **戻す**：`worker_done` ＋ report-path を報告（plan 更新＝対象repo側 / card 状態＝基盤 ai-jobs 側の2系統）。報告はポインタ中心・secret なし。

## 詰まった / できない時

- ブロック・情報不足・完了条件を満たせない → 無理に進めない。`jobctl.sh back <card>`（→ready・差し戻し）にするか、running に残して**ブロッカーを報告**し人間ゲートに委ねる。**カードを削除しない**（`差し戻し上限` は 2）。

## review 不要カード

- 「ただ実行するだけ」（`完了条件` にレビュー不要と明記）のカードは `review` を飛ばし `jobctl.sh done <card>`（running→done）。迷えば review に回す（安全側）。

## 関連（重複させない）

- 実行レーン契約：`../ai-jobs/AGENTS.md`（6フォルダ・claim=mv・レビュー pair・worktree 削除）。
- 状態遷移の窓口：plan-ops `jobctl.sh`（基盤 `skills/plan-ops/scripts/`）＝ `claim/review/take/done/back`。掴み(claim)とレビュー取得(take)は起動側/レビュアー、`review` はワーカーが押す。
- loop 起動標準：`loop-runbook.md`（launchd＋dispatcher＋runner 2系統）。
