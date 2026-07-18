分類: skill ／ 種別: 既存改善
規模: フル
形態判定: 単発 ／ 理由: 露出モデルの一決定に全変更が結合し、rollback単位も「.codex/skillsのsymlink再生成」で1つ
並列: 可（実装3レーン・ファイル担当分離） ／ レビュー: 一括（評価01.mdでR01-R12採点）

# Codexスキル露出のagents一本化

## 目的

Codex向けGlobal Skillの露出窓を `~/.codex/skills` から `~/.agents/skills` へ一本化し、`~/.codex` は設定・hooks・rules・custom agents専用にする。境界を `global-skill-registry/AGENTS.md` と各仕事repoの `AGENTS.md` に明記する。正本（`AIエージェント基盤/skills/`）は動かさない。

狙いは、現在Codexで全Global Skillが二重登録されコンテキストを浪費している実害の解消と、Codex固有設定の置き場の責務明確化。

## 非対象

- 正本 `AIエージェント基盤/skills/` の本文変更。
- `~/.claude/skills`（Claude窓）と `~/.gemini/...`（Gemini窓）の露出方式の変更。
- OpenCodeの露出経路の実移行（`global-skill-registry/AGENTS.md` の誤記訂正だけ行い、`~/.claude/skills` 参照への実切替は未確定4次第で別計画）。
- Hermes Agent の external_dirs 導入・自己改善ゲート設計。
- manifest形式の恒久標準化（今回は「最小改修」か「軽量manifest」の選択と実装まで）。
- standup孤立・plan-management旧名ログ残存の整理（監査Dの副産物・別タスク）。

## 現状

自前の隔離実験（`codex debug prompt-input`・課金なし）とサブエージェントA〜E（2026-07-18）で確定した事実:

- **Codex 0.144.1 は4パスを同時走査し重複排除しない**: `~/.codex/skills`・`~/.agents/skills`・プロジェクト`.codex/skills`・プロジェクト`.agents/skills`。同名を複数窓に置くと統合されず2件別々に注入される。
- **実機は全Global Skillを `~/.codex/skills` と `~/.agents/skills` の両窓にミラー中**＝Codexは今まさに全Skillを二重注入している（監査D）。
- **Codexの skill-creator/skill-installer は新規Skillの既定作成先が `$CODEX_HOME/skills`（=`~/.codex/skills`）**。「.codexにSkillを置かない」は自動では保てず生成物が戻る。
- Claude Code は `.agents` を読まず `~/.claude/skills` のみ。skill単位symlinkは公式サポート＋重複排除、フォルダ全体symlinkは退行歴あり。`CLAUDE.md→AGENTS.md` symlinkは公式推奨（＝指示書レイヤは現状維持でよい）。
- OpenCode 1.1.36 は実機で `~/.agents/skills` を読まない（`global-skill-registry/AGENTS.md` の「OpenCodeは.agents経由で露出」は実態と食い違う）。
- 現行 `link-global-skill.sh` は5窓へ無条件一括symlinkし、選択露出モードが無い。Claude専用（kickoff/morning-routine/sns-post）は手動で単一窓に張って実現＝ヒューマンエラー依存。

研究レポート（Artifact）は session 541fd364 で公開。サブエージェントA・Dの詳細も同session。

## 決定（2026-07-18 人間承認「このまま実装」で確定）

1. **軽量manifest駆動の選択露出**を採用。既定露出窓＝`.agents`（Codex+共通）/`.claude`/`.gemini/config`/`.gemini/antigravity-cli` の4窓（`.codex/skills` は既定から除外）。manifestは**例外だけ列挙**（claude限定などデフォルトと違うskillのみ）＝第2の正本にしない。
2. **Codex自動生成Skillは `.codex/skills` をCodex専用scratchとして容認**。drift-checkが `.agents` と同名の重複を検出したら警告。正本化したい時だけ手動で正本へ移送しescalate。
3. **Claude専用Skill（kickoff/morning-routine/sns-post）は `.agents` に出さない＝確定**（manifestで claude 限定）。
4. **OpenCodeは今回はAGENTS.md誤記訂正のみ**。`~/.claude/skills` 参照への実切替は別計画。

### スコープ外フラグ（監査で判明・別タスク）
- `起業スキル/skills/*`（ai-news-short-video 等5件）が repo-local ながら `.codex`/`.agents` 両窓にミラーされ二重登録中。link-global-skill.sh管理外のため本計画では触らず、repo-local Skill露出の別計画で扱う。
- standup孤立・plan-management旧名ログ残存（監査Dの副産物）。

## 実行契約

- 対象repo: private-meta（`~/Private`。`personal-os/AIエージェント基盤/` と各仕事repoの `AGENTS.md`）
- 実行形: delegated-parallel（実装3レーン・ファイル担当分離）＋私が順次の symlink移行・検証＋評価サブエージェントでR01-R12採点
- ファイル担当マップ:
  - レーンA（コード）: `global-skill-registry/scripts/link-global-skill.sh`（改修）・`global-skill-registry/scripts/exposure-manifest.tsv`（新規）・`global-skill-registry/scripts/check-exposure.sh`（新規drift-check）
  - レーンB（registry文書）: `global-skill-registry/AGENTS.md`
  - レーンC（横断・repo文書）: `AIエージェント基盤/GLOBAL_AGENTS.md`・`projects/active/仕事/AGENTS.md`・`projects/active/focusmap/AGENTS.md`
  - 私（順次・人間ゲート）: `~/.codex/skills` の全Global Skill symlink撤去・`codex debug prompt-input`検証・rollback検証
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md`
  2. この計画
  3. `personal-os/AIエージェント基盤/skills/plan-ops`（drift-check雛形の置き場判断）
- 依存成果: なし（研究は完了・本計画に集約済み）
- 変更可能範囲: `global-skill-registry/scripts/link-global-skill.sh`、`global-skill-registry/AGENTS.md`、対象仕事repoの `AGENTS.md`、`~/.codex/skills` と `~/.agents/skills` のsymlink（削除・作成は人間ゲート）、drift-checkスクリプト新規
- 変更禁止範囲: 正本 `AIエージェント基盤/skills/` の本文、`~/.claude/skills`、secret/token/認証値
- worktree方針: 不要（単一レーン・逐次）
- 維持する契約: 正本は1つ（skills/）。露出窓は正本にしない。Claude専用の限定露出を壊さない。
- 検証: `env -i HOME=$HOME PATH=$PATH codex debug prompt-input "x"` で各skillが1回だけ注入されること。drift-checkが二重・欠落を検出すること。
- 停止・エスカレーション条件: symlink削除・script反映・push の前、置き場や露出方針が未確定なら停止して人間へ。
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

正本不変。Part A（露出）→ Part B（.codex設定限定＋AGENTS.md）を逐次。破壊的な一歩は必ず人間ゲート。

Part A（スキル露出）:
1. 現状snapshot（3窓を `readlink` で全ダンプ）。rollbackの素。
2. 露出モデルを明文化（`.agents`=Codex+共通窓／`.claude`=Claude窓／`.gemini`=Gemini窓／`.codex`=設定専用）。skill単位の選択制（未確定1の決定に従う）。
3. `link-global-skill.sh` 改修: roots から `~/.codex/skills` を除外、`~/.agents/skills` を維持、選択露出と `check`/`drift` サブコマンドを追加。
4. dry-run で作成/削除予定を目視。
5. 1 Skill（例: html）でpilot: 現在の二重を確認→`~/.codex/skills/html` 削除（人間ゲート）→`codex debug prompt-input` で1件化＆`.agents`経由の残存を確認→Claude側不変を確認。
6. 全Global Skillへ展開（`~/.codex/skills/<skill>` を撤去。人間ゲート）。
7. drift-check運用に載せる。

Part B（.codex設定限定＋文書化）:
1. `~/.codex` を config.toml / AGENTS.md(symlink) / auth.json / hooks / rules / agents / state・sessions に限定（Global Skillミラーを置かない）。
2. Codex自動生成Skillの方針を確定（未確定2）しAGENTS.mdへ明記。
3. `global-skill-registry/AGENTS.md` に新露出モデルを明記し、OpenCode誤記を実態へ訂正。
4. 各仕事repoの `AGENTS.md` に境界（Codex skill=`.agents/skills`（or正本）／Codex固有hooks・rules・agents・config=`.codex`／1 skill 1窓）を記載。
5. 削除・push は人間承認。`git add -A` を避けパス指定。

## 完了条件（レビュー項目）

実装後にimpl-reviewerが1項目ずつ採点する。「こうなっていれば正しい＋対象明示」形式。

- [ ] R01 `link-global-skill.sh` の露出先配列から `~/.codex/skills` が除去され `~/.agents/skills` は残っている（対象: `global-skill-registry/scripts/link-global-skill.sh`）
- [ ] R02 全Global Skillについて `~/.codex/skills/<skill>` に正本を指すsymlinkが無い（Codexミラー撤去済み）（対象: `~/.codex/skills` 実測）
- [ ] R03 各Global Skillが `~/.agents/skills/<skill>` から正本へ解決でき、`codex debug prompt-input` で各skillが**1回だけ**注入される（二重登録が消えている）（対象: `codex debug prompt-input` 出力）
- [ ] R04 Claude専用Skill（kickoff/morning-routine/sns-post）が `~/.agents/skills` に存在しない（Codexへ漏れていない）（対象: `~/.agents/skills` 実測）
- [ ] R05 `~/.claude/skills/<skill>` の解決先が変更前snapshotと一致（Claude発見に影響なし）（対象: `~/.claude/skills` readlink比較）
- [ ] R06 `~/.codex` 直下に Global Skillのミラーが無く、config.toml/AGENTS.md/auth.json/hooks/rules/agents/state系に限定されている（対象: `~/.codex` 直下）
- [ ] R07 `global-skill-registry/AGENTS.md` に新露出モデル（.agents=Codex+共通／.claude=Claude／.gemini=Gemini／.codex=設定専用）が明記され、旧「OpenCodeは.agents経由」記述が実態へ訂正されている（対象: `global-skill-registry/AGENTS.md`）
- [ ] R08 対象仕事repoの `AGENTS.md` に「Codex skill=.agents/skills（or正本）／Codex固有hooks・rules・agents・config=.codex／1 skill 1窓」の境界が記載されている（対象: 各対象repo `AGENTS.md`）
- [ ] R09 Codex自動生成Skill（skill-creator/installerが `~/.codex/skills` に作る）の扱い方針がAGENTS.mdに明記されている（対象: `global-skill-registry/AGENTS.md`）
- [ ] R10 drift-checkが「`~/.codex/skills` に `.agents` と同名skillがある＝二重」「`.agents` に無いGlobal Skill」を検出できる（対象: drift-checkスクリプト）
- [ ] R11 変更前snapshot（3窓のreadlinkダンプ）が保存され、rollback手順（snapshotから `~/.codex/skills` を再生成）が検証済み（対象: snapshotファイル＋rollback検証ログ）
- [ ] R12 secret/token/認証値の混入なし。symlink削除・push は人間承認を経ている（対象: 全変更・git diff）

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
