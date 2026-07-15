親計画: ../program.md ／ 分類: skill ／ 種別: 既存改善
並列: 可 ／ レビュー: 都度

# plan-opsの入口を短縮

## 目的

計画の機械手続きをまとめた `plan-ops` を、長い説明とscript一覧が混ざった入口から、短いrouterと目的別workflowへ分ける。既存scriptの振る舞い・置き場・テスト契約は変更しない。

## 現状

- `plan-ops/SKILL.md` は110行あり、役割・script詳細・未自動化範囲・規律・早見表を1枚に持つ。
- `new-plan.sh` / `new-child.sh` / `progctl.sh` / `program-lint.sh` / `check-section.sh` / `bucketctl.sh` はすでに責務が分かれており、移動する必要はない。
- 現在のSkill作成規約は `SKILL.md` を70行以内のrouterにし、手順をworkflow、複数箇所で使う判断をreferenceへ分けるとしている。

## 方針

1. `SKILL.md` は70行以内にし、目的、実行できる手続き、workflow振り分け、正本参照、絶対境界だけを残す。
2. `workflows/scaffold-and-update.md` に `new-plan` / `new-child` / `progctl`、`workflows/validate-and-promote.md` に `program-lint` / `check-section` / `bucketctl` を置く。各workflowはscriptの入力、dry-run、書込み条件、失敗時を明示する。
3. `references/script-map.md` にscriptごとの「自動化すること / 自動化しないこと / 所有するpath」を短く集める。運用規則本文は `plan-registry` とareasへリンクし、複製しない。
4. script、template、testsのpathは移動・改名しない。既存テストを全件実行し、呼び出し側が既存pathを使い続けられることを確認する。

## 完了条件（レビュー項目）

- [x] `plan-ops/SKILL.md` が70行以内で、workflowとreferenceを1ホップで指名している。
- [x] 6つの既存scriptのpath、CLI、既定dry-run、書込み条件、手動に残す判断がreferenceまたはworkflowで確認できる。
- [x] `scripts/` と `templates/` のファイル移動・改名が0件である。
- [x] plan-opsの既存テストが通り、`program-lint` がこの親programに違反なしを返す。
- [x] `SKILL.html` が新しいrouter/workflow/reference構成と一致する。
