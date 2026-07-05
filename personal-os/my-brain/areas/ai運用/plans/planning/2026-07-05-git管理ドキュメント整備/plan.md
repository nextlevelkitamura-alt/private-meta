分類: 横断 ／ 種別: 新規作成 ／ 優先: ○

# git管理ドキュメント整備（2repo構造の正本）

## 目的

AIエージェント基盤に「全体のgit管理」を一望できる正本を1つ作る。`~/Private` が2つのgit repoに
分かれている構造（`private-meta` / `ai-agent-foundation`）・各repoが何を追跡するか・`.gitignore`の
再include方針・push先・スマホ(GitHubアプリ)での見方を、人間がすぐ把握できる形で置く。

## 現状（2026-07-05）

- 2repo構造の知識が分散している（`AIエージェント基盤/CLAUDE.md` のgit節、`~/Private/.gitignore`、会話のみ）。
  「`private-meta` を見ても基盤(hooks)の変更が見えない」という混乱が実際に起きた。
- 既存 `AIエージェント基盤/repo-registry/` は移動・登録・削除の履歴ログ。全体像の一望図は無い。
- 事実: `private-meta`＝`~/Private`外側（remote `nextlevelkitamura-alt/private-meta`）。
  `ai-agent-foundation`＝`personal-os/AIエージェント基盤/`（別repo・remote同アカウント）。
  `.gitignore` が `/personal-os/*` を無視し一部mdだけ再include、基盤は非追跡（追跡0件・実測）。

## 方針（未確定）

- 置き場: `AIエージェント基盤/` 配下（`repo-registry/` に統合するか、git管理用の新mdにするかは未確定）。
- 内容案: 2repoの一覧（名前・remote・追跡範囲）／`.gitignore` 再include規則／push先とブランチ／
  2repoにまたがる変更の束ね方／スマホでの見方（アプリでrepoを開く・コミット/コード）。
- 既存 `AIエージェント基盤/CLAUDE.md` git節・`repo-registry` と二重管理しない（正本を1つに寄せ他は参照）。

## 完了条件（レビュー項目）

1. AIエージェント基盤配下に、2repo（`private-meta` / `ai-agent-foundation`）の追跡範囲・remote・push先を一望できる正本mdが1つある。
2. `.gitignore` の personal-os 再include方針と「AIエージェント基盤は別repo」が明記されている。
3. 既存 `CLAUDE.md` git節・`repo-registry` と内容が重複せず、正本が1つに定まっている（他は参照）。
4. secret/token/認証値を含まない。
