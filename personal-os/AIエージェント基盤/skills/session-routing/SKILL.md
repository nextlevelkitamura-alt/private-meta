---
name: session-routing
description: Focusmap Dailyの未分類セッションを、現在のrepo・今日のTheme・Planと照合し、既存Plan、Theme内作業、Plan候補、Theme候補、未分類へ再提案する。Use when ユーザーが「このセッションを分類して」「未分類を整理して」「Theme/Planへの紐付けを見直して」と明示した時。毎Promptの自動分類には使わない。
---

# session-routing

Hookが機械記録した `pending` を、人間と一緒に安全に再分類する。自動Hookから本Skillを呼ばない。

## 1. 入力を確定する

1. 対象の session key（`s:xxxxxxxx`）を確認する。推測で別sessionを触らない。
2. 必要なら対象turn IDを確認する。指定がなければ最新のpendingだけを対象にする。
3. 次のCLIで現在地と候補を読む。

```bash
/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/hooks-registry/shared/session-board/board.py route-context --key <session-key>
```

候補は今日かつ対象repoのTodoを持つThemeと、そのThemeが参照するactive/planning Planだけ。候補が空でも全件検索へ広げない。

## 2. 5分類で提案する

| kind | 境界 |
| --- | --- |
| `plan` | 明示された既存Planの工程を進める |
| `theme_work` | Themeへ直接貢献する小さな単発・計画外修正 |
| `plan_candidate` | 複数工程・複数session・依存・人間ゲートがある |
| `theme_candidate` | 既存Themeと異なる継続目的になりうる |
| `unclassified` | 一回限り、無関係、または判断材料不足 |

特定Planの手直しは `plan`。Theme全体を支える障害除去だけ `theme_work` にする。

## 3. 確定と提案を分ける

次の証拠がある場合だけ `--status accepted` を使う。

- FocusmapのPlanカードから開始した。
- handoffにTheme/Plan IDがある。
- ユーザーが所属先を明示した。
- 同じsessionですでに人間が確定している。

文意が似ているだけなら既定の `proposed` のままにし、理由を1行で示す。

## 4. 専用CLIで書き戻す

```bash
/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/hooks-registry/shared/session-board/board.py route-propose \
  --key <session-key> --turn <turn-id> --kind <kind> \
  [--theme <theme-id>] [--plan <plan-slug>] \
  --summary "<secretを含まない安全な1行>" --reason "<判断理由1行>" [--status accepted]
```

stdoutの`recorded status=...`を確認する。`unchanged status=accepted`は採用済み行を保護した正常結果、`unavailable`はDB未接続・migration未適用のため未確認であり、成功扱いにしない。

## 5. 境界

- SQLを直接実行しない。prompt全文、remote URL、token、credentialを保存しない。
- Theme・Planを自動作成しない。候補採用と計画化は人間ゲートへ戻す。
- Plan本文・Plan状態の正本はrepo Markdown。Turso側へ本文を複製しない。
- session状態はsession-board、分類提案はrouting表、画面表示はFocusmapが所有する。
