# ai-jobs — AI実行レーン（spool）

> **稼働状態: 休眠（2026-07-03裁定・マルチ指揮官体制program）。新しい計画の受け渡しにここを使わない。**
> - 理由: ai-jobsの固有機能は「調停者なしで複数ワーカーが同じ待ち行列を取り合ってもアトミック（mv）に受け渡せる」こと。現在の運用は契約§1モードB（全体管理者=単一の振り分け役がテキスト状態で配る）であり、振り分け役が1人いる間はこの機能を使う場面がない。依頼の入口はデイリーの依頼インボックス節（Notionは遠隔入力口）、采配は全体管理者のsend、進捗は行末注記＋レーン実況が担う。
> - 再開（モードA昇格）の条件: 正本は `../../../説明書/運用契約.md` §1 — ①モードBで安定した定型処理2本以上が同じ列を同時に取り合う状態になった ②ai-jobs-dispatcherのスモークテスト合格、の両方を満たし人間が承認した時。
> - それまでフォルダ・dispatcher・branch・本AGENTS.mdは温存する（削除しない）。以下の運用ルールは再開時のためにそのまま残す。

`ready/` に run-card を置くと、AIワーカー（Orca / Codex / Claude）が拾って実行する待ち行列。
**計画ではなく実行**を扱う。計画ツリー（`../my-brain/areas/<area>/plans/`）とは別レイヤー。
`CLAUDE.md` は同階層の `AGENTS.md` への相対symlink。

## 1. 状態＝フォルダ位置（これが正本）

```text
ai-jobs/
  ready/      置いたら実行してよい（launchd / loop が拾う）
  running/    実装中（mv で所有＝二重実行防止）
  review/     実装済み・レビュー待ち（実行だけのものは飛ばす）
  reviewing/  レビュー中（mv で所有＝二重レビュー防止）
  done/       レビュー合格・確認待ち
  archive/    確認済み（done→archive は「本当に終わった?」確認loopが動かす）
```

1. run-card の中に `状態:` を書かない。**フォルダ位置が状態の正本**。
2. 発見は `ls ready/`（中身を解析しない）。掴むのは `mv ready/<card> running/`（OSレベルでアトミック＝奪い合い防止）。レビューの取得も同様に `mv review/<card> reviewing/`（アトミック＝二重レビュー防止）。
   実務では plan-ops の `jobctl.sh`（基盤 `skills/plan-ops/scripts/`）を使う。base を絶対パスで固定するので cwd 非依存で、上書き・誤削除を防ぐ（素の `mv` はカレント依存で誤りやすい）。claim/review/take(レビュー取得)/done/差し戻し(back)も同じ窓口。
3. 掴んだ後に run-card 本文を読み、`担当` の engine で実行する。実行の手順（読む→worktree→完了条件→review へ渡す）は `../references/worker-prompt.md`（worker型）。run-card は plan-ops `new-run-card.sh` で計画(出所)から雛形生成できる（出所パス自動・項目漏れ防止）。

## 2. run-card の形

repo-aware。出所（計画）と対象repo（作業先）が別のこともある（卒業した計画）。card 1枚で対象repoに入って実行できる。

```text
担当: codex                          # codex / claude / orca
出所: <計画への絶対パス>               # 例 ~/Private/.../plans/active/<program>/plans/05-*.md
対象repo: <作業するrepoのルート絶対パス>   # 出所と同じこともある
作業導線: <対象repo>/AGENTS.md を先に読む
ブランチ: <既存branch / 新規 feature/xxx / worktree指定>
依頼: <自己完結した実行指示>
許可: <触ってよいファイル / 範囲>
前提: <必要な env / CLI / サービス名のみ・値は書かない>
完了条件: <出所のレビュー項目を満たすこと>
戻し方: worker_done + report-path（plan更新=対象repo側 / card状態=基盤ai-jobs側の2系統）
差し戻し上限: 2
```

最小（同一repo・即実行）の場合は `対象repo/作業導線/ブランチ/前提` を省いてよい。別repoへ卒業した計画を実行する時はこの全項目を埋める。

## 3. 流れ

`ready →(claim:mv)→ running →(実装完了)→ review →(claim:mv)→ reviewing →(合格)→ done →(確認loop)→ archive`

1. review 不要（ただ実行するだけ）の card は `running → done`（または直 `archive`）。`reviewing` も飛ばす。
2. レビュー合格 → `mv reviewing/ done/`。不合格 / 失敗 → `ready` へ戻す（差し戻し・上限2）or 人間ゲート。**削除しない**。
3. `done` に入るのは `reviewing` を通った（レビュー合格の）card だけ。「レビュー前に done」は禁止。
4. 完了したら plan-ops が出所の計画（program.md マップ / 子.md）を更新する。

## 4. 規律

1. **human 作業は入れない。** ここは AI / 自動実行レーン。人間のやることは計画ツリー側（マップの「次の一手」/ 子.md）。
2. run-state を計画バケットにコピーしない。橋渡しは plan-ops が「ジョブ→計画」へ集約するだけ（`../my-brain/areas/AGENTS.md` §4）。
3. secret / token / 認証値を run-card・ログに書かない。
4. 前回 run が `running/` に残っている間は、同じ card の新 run を増やさない。
5. worktree は **レビュー合格＆反映の後**に消す（`done→archive` 以降）。`reviewing` 中はレビュアーと差し戻し修正が同じ worktree を使うので、それまで消さない。

## 5. git

`ready/running/review/reviewing/done/archive` の**中身（run-card）は非追跡**（揮発状態）。構造（`.gitkeep`）とこの `AGENTS.md` だけ追跡する。規則は基盤 `.gitignore`。
