# plan-ops script map

このSkillが呼ぶ実体はすべて `scripts/` の固定pathにある。ここでは「何を機械化するか」と「手動に残す判断」を区別する。規模・状態語彙・人間ゲートの本文は `GLOBAL_AGENTS.md` とareaの `AGENTS.md` を正本とし、ここへ複製しない。

| 固定path | 自動化すること | 手動に残すこと | 書込み条件 |
|---|---|---|---|
| `scripts/new-plan.sh` | plan / programテンプレを指定絶対pathへ生成 | 置き場・内容・既存planとの合流判断 | 新規pathのみ。既存を上書きしない |
| `scripts/new-child.sh` | 子テンプレ生成と親への相対backlink | 子計画マップの新規NN追加、内容判断 | 新規pathのみ。既存を上書きしない |
| `scripts/progctl.sh` | 既存NNのstate / next / refを冪等に差分化 | 新しいNN、状態の意味、記入内容 | 既定dry-run。`--commit`で適用・定型commit |
| `scripts/program-lint.sh` | 親子対応・backlink・状態語彙・完了条件を静的検査 | 内容の妥当性・レビュー合否・承認 | 読み取り専用 |
| `scripts/plan-lint.sh` | plan / 子計画 / program の実行契約、必須節、placeholder、並列レーン宣言を静的検査 | 計画内容の妥当性・レビュー合否・承認 | 読み取り専用 |
| `scripts/check-section.sh` | 指定節だけを表示・pattern照合 | 一致の意味とレビュー合否 | 読み取り専用 |
| `scripts/bucketctl.sh` | 許可遷移、容量、終了記録を検証したdry-run / `git mv` / 定型commit、`check --json` | 優先順位、終了理由、人間確認の判断 | 既定dry-run。`--apply` / `--commit`は明示時だけ |
| `scripts/planctl.py` | manifest/Task Packet生成、子進捗、評価同期、終了記録、整合検査、日付rename | 対象計画の推測、評価の意味判断、人間のクローズ判断 | 明示pathのみ。manifestはgitignore配下 |
| `scripts/plansync.py` | active計画mdをinbox DB(plan_docs/plan_progress)へ一方向ミラー。抽出・kind分類・子N/M・完了条件x/y・secret拒否・孤児DELETE | md本文の編集（正本はmd）、migration適用可否、初回投入GO | 既定dry-run（`scan`/`sync`）。`--apply`で書込（人間ゲート後）。パーサは`_planops_map`流用・送信は session-board `turso/store.py`流用 |
| `scripts/plansync-post-commit.sh` | ~/Private commit時の差分計画mdを差分ミラー（多重ロック・失敗spool退避） | .git/hooksへの登録（人間ゲート） | `--apply`実書込。登録は人間 |

## 同じ場所に残すもの

```text
plan-ops/
├── scripts/       # 上のCLIと内部Python。移動・改名しない
├── templates/     # plan / program / 子計画 / 評価 / 修正 / Task Packet / result / 終了記録の正本
└── __tests__/     # script契約の回帰テスト
```

テンプレから生成されない `評価.md` と `修正.md` は、対象planの評価・修正文書を作る時に手でコピーして使う。いつ評価するか、誰がレビューするか、何を完了とするかはこのSkillでは決めない。

## 検証コマンド

scriptの変更または入口文書とCLIの整合確認後は、次を実行する。

```bash
bash __tests__/run.sh
```

このテストはscriptの既定dry-run、書込み保護、backlink、program-lint、plan-lint、遷移・容量、終了記録、evaluation同期を検査する。雛形は `plan-lint.sh <path> --allow-placeholders` で検査でき、実行開始前はallow無しで通す。workflow / referenceだけを変更した場合でも、CLI説明が実装と一致することを手動で突き合わせる。
