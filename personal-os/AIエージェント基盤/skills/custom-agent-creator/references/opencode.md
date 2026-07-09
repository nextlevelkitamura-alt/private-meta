# OpenCode / OpenCode Go agent

OpenCode の primary agent / subagent を作るための reference。`SKILL.md` の読み分けで OpenCode が対象のとき読む。

注意: OpenCode のキー名と、特に OpenCode Go の model ID はバージョンで変わる。下の model 用途対応は「当て方の例」であり、model ID は実装時に必ず公式・実環境で確認する。具体的な model ID を断定してハードコードしない。

## 目次

1. OpenCode agent とは / 2. 保存先 / 3. primary と subagent / 4. 基本構造 / 5. 主な設定項目 / 6. permission / 7. OpenCode Go の model routing / 8. 推奨 agent / 9. テンプレート

## 1. OpenCode agent とは

OpenCode 内で使う専門エージェント。主に primary agent と subagent を作る。OpenCode Go を使う場合は agent ごとにモデルを明示して呼び分ける。

## 2. 保存先

1. 個人共通: `~/.config/opencode/agents/<agent-name>.md`
2. プロジェクト専用: `.opencode/agents/<agent-name>.md`

## 3. primary と subagent

1. primary agent: 人間が直接対話するメイン。planner / builder / reviewer mode / 特定モデルの作業モード。
2. subagent: primary から呼ぶ専門。code review / security audit / docs / 探索 / cheap executor。

## 4. 基本構造

```markdown
---
description: 変更差分をレビューし、品質・セキュリティ・回帰を確認するquality gate。
mode: subagent
model: opencode-go/<model-id>
temperature: 0.1
permission:
  edit: deny
  bash:
    "*": ask
    "git diff*": allow
    "git status*": allow
    "rm *": deny
    "git push*": deny
---
あなたは品質ゲート担当です。
ファイルは編集しないでください。
```

## 5. 主な設定項目

1. `description`: 何をする agent か。
2. `mode`: `primary` / `subagent` / `all`。
3. `model`: 使用モデル。
4. `temperature` / `top_p`: 出力の揺らぎ / 多様性。
5. `steps`: 最大ステップ数。
6. `permission`: 権限設定（§6）。
7. `hidden` / `color` / `prompt`: 補完から隠す / 表示色 / system prompt。

## 6. permission

値: `allow`（許可）/ `ask`（確認）/ `deny`（拒否）。

方針: reviewer は `edit: deny`。bash は原則 `ask`。`git diff*` / `git status*` は `allow`。`rm *` / `git push*` は `deny`。`--auto` 前提の設計にしない。

## 7. OpenCode Go の model routing

```yaml
model: opencode-go/<model-id>
```

model ID は最新化されるため、下記は用途別の当て方の「例」。具体名は実装時に確認する。

1. 計画・設計: 強めの汎用モデル。
2. 高難度設計: 最上位の設計モデル。
3. 実装: コード特化モデル。
4. 軽い実行・探索: 安い高速モデル。
5. レビュー: 中〜強のレビュー向きモデル。
6. 高リスクレビュー: 最上位モデル。

方針: 最強モデルを常用しない。探索・軽作業は安いモデルに寄せる。reviewer / security / planner は強めのモデルを使う。

## 8. 推奨 agent

1. `go-planner`: 設計・計画。primary または subagent。
2. `go-builder`: 実装。primary 向き。
3. `go-executor-fast`: 軽作業。subagent 向き。
4. `go-quality-gate`: レビュー。subagent。
5. `go-security-auditor`: 高リスクレビュー。subagent。

## 9. テンプレート: go-quality-gate

```markdown
---
description: 変更差分をレビューし、品質・セキュリティ・回帰・テスト不足を確認するquality gate。review、evaluator、security checkが必要なときに使う。
mode: subagent
model: opencode-go/<model-id>   # 実装時に確認
temperature: 0.1
permission:
  edit: deny
  bash:
    "*": ask
    "git diff*": allow
    "git status*": allow
    "git log*": allow
    "rm *": deny
    "git push*": deny
---
あなたは品質ゲート担当です。
ファイルは編集しないでください。
現在の差分だけを対象にレビューしてください。
確認すること:
- 正しさ / 回帰バグ / セキュリティ / テスト不足 / 仕様とのズレ
出力形式:
1. Verdict: APPROVED / WARNING / BLOCKED
2. 重要な指摘
3. 必須修正
4. 実行すべきテスト
```
