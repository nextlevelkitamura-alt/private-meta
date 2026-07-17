親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル

# 08 Focusmapガバナンス適用

## 目的

子04のGlobal contractをFocusmap repo-local自動処理へ適用し、Focusmap内のmanifest / registry / verifyを整える。Global側へFocusmap本文をコピーせず、実装も移動しない。

## 現状

- `.claude` / `.codex` hooks、focusmap-agent内部loop、Codex app-server、旧task-runner、Web pollが別々のdoc / codeに散在する。
- Focusmapにはrepo-local自動処理一覧とverifyがない。
- 実装とruntimeのlabel / processが一致せず、React `src/hooks/`との用語混同も起きやすい。

## 方針

人間確認後、次の最小構造をFocusmap repoへ置く。

```text
docs/automation/
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── registry.md
└── units/<id>.md
scripts/automation/verify.mjs
```

- unit manifestは子04のcontractを参照し、本文をコピーしない。
- runtime shim / agent実装 / plistは初手で移動しない。
- registryは現役・停止・legacyを分け、意図状態と実機状態を別に表示する。
- verifyはsettings / hooks index / plist / entrypoint / process / replacementをローカルで検査する。
- React custom hookはunitにしない。poll / watchはWeb consumerとして論理unitへ紐づける。
- Cloud公開payload生成は子07へ委ねる。ローカル詳細をそのまま返さない。

## 完了条件（レビュー項目）

- [ ] Focusmap repo-local全unitがregistryにあり、Global一覧との二重正本になっていない。
- [ ] `.claude` / `.codex` hooks、agent内部4 loop、app-server、Mac supervisor、旧runner、主要Web pollが分類される。
- [ ] React `src/hooks/`がruntime hookとして登録されていない。
- [ ] verifyがsettings / hooks index / plist / entrypoint / processの意図と実機の差を検出する。
- [ ] legacy unitにreplacement、残責務、削除条件、人間ゲートがある。
- [ ] Global contract本文をFocusmapへコピーせず参照している。
- [ ] ローカルverify詳細とCloud公開payloadの境界が子07に委譲されている。
