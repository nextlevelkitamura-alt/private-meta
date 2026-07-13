親計画: ../program.md ／ 分類: loop ／ 種別: 既存改善 ／ 規模: フル

# 04 Hooks / Loopsガバナンス標準

## 目的

Global自動処理のcontractをAIエージェント基盤に1つだけ定義する。新しいGlobal hook / loop / serviceを追加する時の置き場、必須manifest、検証、寿命、人間ゲートを固定する。Focusmapへの適用は子08が担当する。

## 現状

- Global loopsは `loops/<id>/loop.md + plist + scripts` と一覧 / verifyがあり成熟している。
- Global hooksは共有本体とruntime shimの境界は明確だが、`hook.md`、一覧正本、verifyがない。
- runtime登録 / loaded / process /文書本文のドリフトを一度に検査できない。

## 方針

### 共通contractの正本

Global側に `自動処理契約.md` を1枚だけ置き、本文を各AGENTSや子01へコピーしない。子01の採取項目を材料にし、完成後はこのファイルだけを恒久contract正本とする。

### 目標構造（人間承認後に作る）

```text
AIエージェント基盤/
├── 自動処理契約.md
├── hooks-registry/
│   ├── hooks/<id>/hook.md
│   └── 実行一覧/{AGENTS.md, CLAUDE.md, personal-os.md, personal-os.html, verify.py}
└── loops-registry/
    ├── loops/<id>/loop.md       # 既存を共通schemaへ追従
    └── 実行一覧/*               # 既存維持
```

runtime shimや実装本体は初手で移動しない。Global一覧はrepo-local本文を持たず、外部repo unitの存在とownerだけを索引できる。

### verifyの検査範囲

- manifest必須項目とID重複。
- entrypoint / plist / ProgramArguments / runtime settings / hooks indexの実在。
- symlink最終実体。
- 意図状態と実機loaded / process状態の差。
- stop / rollback / human gate / test pathの存在。
- legacy unitのreplacement / removal gate。
- ローカルverify JSONは子07のpublisher入力に使えるが、Cloud公開schemaとは分離する。

### 寿命

draftはplan、現役だけregistryへ入れる。pauseは理由・期限、legacyはreplacement・削除条件を必須にする。追加・発火変更・停止・再開・廃止は人間ゲート。

## 完了条件（レビュー項目）

- [ ] 共通contractが1正本で、hook / loop / service / internal-loopの必須項目を定義している。
- [ ] Global session-boardにhook manifestがあり、Claude / Codex runtime登録と共有本体を解決できる。
- [ ] Global hook一覧 / verifyがloop一覧と同等に、実体・登録・symlink・意図 / 実機状態を検査する。
- [ ] 既存4 loopのmanifestが共通schemaへ追従し、既存 `verify.py` の契約を壊さない。
- [ ] paused / legacy unitに理由・期限・replacement・削除ゲートがある。
- [ ] ローカルverify JSONにsecret値が0件で、Cloud公開対象は子07のallowlistへ委ねている。
