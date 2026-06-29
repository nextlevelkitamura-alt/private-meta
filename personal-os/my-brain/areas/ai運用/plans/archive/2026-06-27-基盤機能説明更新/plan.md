分類: skill
種別: 既存改善

# AIエージェント基盤の機能説明更新計画

- 種別: 既存改善
- 変更内容: docs反映
- 目的: AIエージェント基盤が管理する機能として、Global Skill正本、runtime露出、logs、catalogに加えて、Skill計画書の格納・更新場所も説明できるようにする。
- 対象: `README.md`、`AGENTS.md`、`skill-plans/AGENTS.md`、`skills/skill-creator-custom/`、`skills/skill-creator-codex/`
- 判断: まず `skill-plans/` を独立した計画置き場として明示し、詳細な運用は `skill-plans/AGENTS.md` に寄せる。

## 実行順

1. `skill-plans/` の役割と計画書の状態管理を定義する。
2. `AGENTS.md` に、Skill計画書の正本場所、触る場所、作業前チェック、完了条件を短く追加する。
3. `README.md` に、人間向けの機能一覧として `skill-plans/` を追加する。
4. `skill-creator-custom` に、中〜大規模なSkill作成・改善では計画書を使う判断を追加する。
5. `skill-creator-codex` に、北村環境の中〜大規模Global Skill作成・改善で計画書運用に接続する判断を追加する。
6. `catalog/CLAUDE.md` と `skill-plans/CLAUDE.md` のsymlinkを構成に反映する。
7. 変更後に、Skill本体、logs、catalog、計画書の責務が混ざっていないか確認する。

## 完了条件

1. `skill-plans/` が、Skill本体・履歴・索引ではなく計画置き場として説明されている。
2. `README.md` から、Skill計画書の格納・更新場所が分かる。
3. `AGENTS.md` から、作業前に計画書を作るべき場面が分かる。
4. `skill-creator-custom` から、大きめのSkill作成時に `skill-plans/` を使う判断が分かる。
5. `skill-creator-custom` のレビュー導線から、大きめの既存Skill改善時に `skill-plans/` を確認できる。
6. `skill-creator-codex` から、北村環境のGlobal Skill作成・改善時のlogs/catalog/skill-plans報告が分かる。

## 結果

1. `skill-plans/AGENTS.md` を追加し、計画書の状態管理を定義した。
2. `AGENTS.md` と `README.md` に、Skill計画書の格納・更新場所を追加した。
3. `skill-creator-custom` の新規作成・レビュー導線に `skill-plans/` 確認を追加した。
4. `skill-creator-codex` に、北村環境のGlobal Skill作成・改善時の計画書確認と最終報告項目を追加した。
5. `catalog/CLAUDE.md` と `skill-plans/CLAUDE.md` を `AGENTS.md` への相対symlinkとして扱う構成にした。

## logs/catalog

- logs: Skill作成・移行・削除・改名ではないため更新不要。
- catalog: Skillの追加・削除・分類変更ではないため更新不要。

## 保留事項

- なし
