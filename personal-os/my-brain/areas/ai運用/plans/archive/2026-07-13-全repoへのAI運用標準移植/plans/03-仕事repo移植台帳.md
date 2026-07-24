親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: ライト
並列: 可（A01〜A04 read-only） ／ レビュー: Review 1へ集約

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

## 実行パッケージ

1. **A01 plan実体**: 領域canonical候補、root bucket、補助文書を区別し、metadata/header形式と実状態根拠を列挙する。
2. **A02 consumer graph**: reader/writer、`#plan` alias、schedule、AGENTS、Skill、script、HANDOFFを逆引きする。
3. **A03 ownership/path**: AGENTS/CLAUDE、Skill symlink、旧絶対path、外部副作用を正本/露出/現役/履歴へ分類する。
4. **A04 hook/loop/runtime**: repo-local/global hook、load済みloop、plist正本/runtimeの対応を値なしで実測する。
5. **A05 台帳統合**: A01〜A04の同一snapshot結果を、指揮官1名だけが `references/仕事repo移植台帳.md` へ統合する。

## 並列・証拠・rollback

- A01〜A04はファイル編集なしで並列可。subagentは中央referenceや仕事repoを書かず、snapshot ID付き報告だけを返す。
- A05は1 writer。計画path重複0、全consumerにread/write区分、全entryに正本/露出/外部副作用/判断を持たせる。
- 本Childのrollbackは中央台帳差分のrevertだけ。仕事repoのGit状態が開始snapshotから変われば監査を無効化して再取得する。

## 完了条件（レビュー項目）

- [x] `references/仕事repo移植台帳.md` に全 `領域/**/計画/*`、root `plans/*`、`計画一覧.md` が重複なく列挙されている。
- [x] 各計画に「現在の正本」「対象領域/プロジェクト」「計画類型」「正しい計画箱」「実状態の根拠」「consumer」「判断」「人間ゲート」がある。
- [x] activeなAGENTS/Skill/script/hookから旧計画・旧rootへ向く参照が全件一覧化されている。
- [x] 履歴文書・生成物・停止済み資産が、現役参照の一括置換対象に混ざっていない。
- [x] 仕事repoの `領域/`、manual、scripts、MCP、稼働loopが移植対象外として明記されている。
- [x] 台帳作成前後で仕事repoのtracked file内容とGit状態が変わっていない。

## 実装記録

2026-07-13、Terra 3レーンのA01〜A04 read-only監査を同一snapshotで統合し、`../references/仕事repo移植台帳.md` をA05単独writerで作成した。仕事repoは開始/終了とも `master@6e0862e53a93`、dirtyはGate 0の10pathだけで変化0。正式採点はReview 1へ集約する。
