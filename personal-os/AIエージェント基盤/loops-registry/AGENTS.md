# loops-registry — loop 運用の一式

Global loop の運用一式（実行レーン・loop本体・共通参照・loop計画）を集める場所。
`global-skill-registry/`（skill 側）と対称。`CLAUDE.md` は `AGENTS.md` への相対symlink。

## 構成

```text
loops-registry/
  references/       全loop共通の参照
    loop-runbook.md   起動の仕組み（launchd＋dispatcher＋runner ai/script）
    loop-types.md     実行方式の選び方（①キュー→Orca ②headless ③hook）
    worker-prompt.md  worker が run-card 1枚を実行する手順の型
  ai-jobs/          AI実行レーン（spool）。運用の正本は ai-jobs/AGENTS.md
  loops/            loop 本体
    ai-jobs-dispatcher/  ③④ headless dispatcher＋stale回収（plist未ロード=人間ゲート・停止）
    daily-digest/        ⑥ 夜loop: renderer/へ委譲する薄いラッパ（停止 2026-07-04）
    renderer/            統合デイリーレンダラv1: テンプレ生成＋auto:goal/log backfill/done/align冪等生成
                          （生成ロジックの正本。停止 2026-07-04・hook撤去済み）
    exec-audit/          launchd 構造ドリフト検出（月木10:00・検出=②script／対応=①Orca・停止 2026-07-04）
    <loop名>/            loop.md（実行スペック）＋任意 scripts/・references/
  実行一覧/         launchd 自動実行の横断インデックス（repoごと md・実体の正本は各repo）
  plans/loop/       卒業してきた loop 計画（未生成・初回卒業で生やす）
```

## 規律
- `loop.md` は実行スペック（目的・起動条件・各回の実行・完了/停止条件・対象/設定・ログ先）。稼働状態（稼働中/停止/廃止）は `loop.md` frontmatter で持つ（フォルダで分けない）。
- コードは `loops/<loop>/scripts/` に置く。`plans/loop/`（計画）にコードを置かない。
- `ai-jobs/` の実行レーン運用（ready→running→review→reviewing→done→archive、claim=mv、run-card形式）は `ai-jobs/AGENTS.md` が正本。
- 実行方式の選び方（headless/hook/キュー）は `references/loop-types.md`。起動の仕組みは `references/loop-runbook.md`。
- global か特定repo専用かは基盤 `AGENTS.md` の「Global か repo-local か」で決める。特定repo専用 loop の実体は `projects/<repo>/`、ここには登録だけ。

## loop 計画
- 育成は `../../my-brain/areas/ai運用/plans/`、卒業先は `plans/loop/<状態>/<YYYY-MM-DD-日本語企画名>/plan.md`。
- 状態は6バケット（planning/ready/active/paused/done/archive）。語彙の正本は `../../my-brain/areas/AGENTS.md` §4。
- `loop.md` と plan は相互参照（`loop.md` frontmatter に `設計:`、plan の完了条件で成果 `loops/<loop>` を指す。名前を対応させる）。
