親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: ライト
並列: 不可 ／ レビュー: 都度

# 仕事repo移植台帳

## 目的

ファイルを動かす前に、旧計画、consumer、旧絶対path、正本所有者を対応づけ、各移行波の対象と触らない範囲を固定する。

## 現状

1. `領域/**/計画/` のlegacy計画、手書き `計画一覧.md`、root `plans/planning/` が併存する。
2. `task`、`eod`、`review`、`repo-eval` 等の複数Skillが旧計画一覧や旧pathを読む・更新する。
3. 旧rootへの絶対path参照が多数あり、現役hook/scriptと履歴文書を同じ扱いにできない。
4. root plans内にも既存計画があるため、領域固有・複数領域・repo基盤のどれに属するかと、名前・目的の重複確認が必要である。

## 方針

1. 全repo移植の計画正本は中央program一式のまま増やさず、本programの `references/仕事repo移植台帳.md` だけを仕事移植台帳の正本にする。仕事repoへ同じprogramや台帳を複製しない。
2. 各既存計画に、現path、対象領域/プロジェクト、実状態の根拠、計画類型（領域固有/repo横断）、正しい計画箱、consumer、外部副作用、判断（現状維持/形式整理/移動候補/履歴化/対象外）を1行で持たせる。
3. `計画一覧.md`、AGENTS、Skill、script、schedule、hookから計画へ向く参照を逆引きする。
4. 旧絶対pathは現役・履歴・生成物・外部登録に分類し、文字列の全置換をしない。
5. Global Skill symlink、repo-local Skill、repo-local hook/loop、manualを所有者別に分類する。
6. 領域固有計画をrootへ集約することを前提にしない。誤配置が疑われても、本子計画では移動・改名・symlink変更・commitを行わない。

## 完了条件（レビュー項目）

- [ ] `references/仕事repo移植台帳.md` に全 `領域/**/計画/*`、root `plans/*`、`計画一覧.md` が重複なく列挙されている。
- [ ] 各計画に「現在の正本」「対象領域/プロジェクト」「計画類型」「正しい計画箱」「実状態の根拠」「consumer」「判断」「人間ゲート」がある。
- [ ] activeなAGENTS/Skill/script/hookから旧計画・旧rootへ向く参照が全件一覧化されている。
- [ ] 履歴文書・生成物・停止済み資産が、現役参照の一括置換対象に混ざっていない。
- [ ] 仕事repoの `領域/`、manual、scripts、MCP、稼働loopが移植対象外として明記されている。
- [ ] 台帳作成前後で仕事repoのtracked file内容とGit状態が変わっていない。
