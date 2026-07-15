# plan-ops script map

このSkillが呼ぶ実体はすべて `scripts/` の固定pathにある。ここでは「何を機械化するか」と「手動に残す判断」を区別する。規模・状態語彙・人間ゲートの本文は `GLOBAL_AGENTS.md` とareaの `AGENTS.md` を正本とし、ここへ複製しない。

| 固定path | 自動化すること | 手動に残すこと | 書込み条件 |
|---|---|---|---|
| `scripts/new-plan.sh` | plan / programテンプレを指定絶対pathへ生成 | 置き場・内容・既存planとの合流判断 | 新規pathのみ。既存を上書きしない |
| `scripts/new-child.sh` | 子テンプレ生成と親への相対backlink | 子計画マップの新規NN追加、内容判断 | 新規pathのみ。既存を上書きしない |
| `scripts/progctl.sh` | 既存NNのstate / next / refを冪等に差分化 | 新しいNN、状態の意味、記入内容 | 既定dry-run。`--commit`で適用・定型commit |
| `scripts/program-lint.sh` | 親子対応・backlink・状態語彙・完了条件を静的検査 | 内容の妥当性・レビュー合否・承認 | 読み取り専用 |
| `scripts/check-section.sh` | 指定節だけを表示・pattern照合 | 一致の意味とレビュー合否 | 読み取り専用 |
| `scripts/bucketctl.sh` | planning→activeのdry-run / `git mv` / 定型commit | 優先順位、退避先、archive・卒業・削除 | 既定dry-run。`--apply` / `--commit`は人間承認後 |

## 同じ場所に残すもの

```text
plan-ops/
├── scripts/       # 上の6 CLIと内部Python。移動・改名しない
├── templates/     # plan.md / program.md / 子計画.md / 評価.md / 修正.md の正本
└── __tests__/     # script契約の回帰テスト
```

テンプレから生成されない `評価.md` と `修正.md` は、対象planの評価・修正文書を作る時に手でコピーして使う。いつ評価するか、誰がレビューするか、何を完了とするかはこのSkillでは決めない。

## 検証コマンド

scriptの変更または入口文書とCLIの整合確認後は、次を実行する。

```bash
bash __tests__/run.sh
```

このテストはscriptの既定dry-run、書込み保護、backlink、lint、WIP上限を検査する。workflow / referenceだけを変更した場合でも、CLI説明が実装と一致することを手動で突き合わせる。
