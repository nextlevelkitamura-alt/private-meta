分類: skill
種別: 新規作成
規模: ライト

# メタ説明skill（meta-explain）の新設

## 目的

AIがメタ領域（hook・Skill・loop・registry・runtime露出・AGENTS・計画構造）を触る前後で、「現状どう動いているか（→どう変えるか→新しい本文はどうなるか）」を人間が理解しきるまでHTML(Artifact)で説明・反復更新する理解ゲートSkillを作る。

狙いは次の3つ。

1. 人間の理解が及ばないままのメタ編集（危険）を実装前に止める。
2. AIの間違い・認識ズレを、人間が最短で見つけて指摘できる状態を作る。
3. 「どういうHTML構成・見せ方ならメタ構造が理解しやすいか」を型として持ち、説明の質を安定させる（このSkillの中核）。

## 現状

- 該当機能を持つSkillは無い。近接（2026-07-11 catalog/meta.md と各SKILL.mdで確認）:
  - `grill-me`: AIが人間へ一問ずつ質問する方向。本件（AIが人間へ説明する方向）と逆で、補完関係。
  - `naiyou-suriawase`: 実行前の軽いテキストすり合わせ（明示依頼時のみ）。深いメタ構造説明は対象外。
  - `html`: 出力面のSkill。何を調べ何を説明するかの判断・反復ループは持たない。新Skillはこれを出力規約として参照する。
- `skill-visualizer` は廃止候補（2026-07-11 サブエージェント調査済み）:
  - 他Skill・loop・hook・scriptからの実行導線（機能依存）はゼロ。
  - 参照はcatalog記載・htmlのblock内の棲み分け文言・移行ログ・runtime symlink 5本（claude/codex/agents/gemini×2）のみ。
  - 廃止はcatalog整理・symlink撤去・削除ログ追記だけで安全に済む。「Skillの図解・理解」用途はmeta-explainが吸収する。
- メタ変更は「できたと思ったら全然できていない」齟齬が起きやすく、実装前の人間理解ゲートが運用上の穴になっている。

## 方針

1. 名前: `meta-explain`（推奨。呼び名「メタエクスプレイン」そのままで最も発火しやすい）。
2. 分類: meta / Global（repo・runtime横断のメタ運用のため）。
3. 構成: `SKILL.md`（40行前後・手順と安全方針だけのスリムな本文）＋ `references/説明の型.md`（中核）。`workflows/` は作らない。
   - `説明の型.md` が持つもの: 説明の原則（全体→差分→本文の順・実ファイル根拠・本文は全文 等）/ 固定7節型 / メタ内容ごとの見せ方マッピング（フォルダ構成=tree・hookの流れ=SVGフロー・設定差分=before/after・本文=codeblock全文 等）/ 理解ループの回し方。
   - 汎用のHTML部品ラダー・表の条件は `html` スキルの `html-structure.md` が正本。`説明の型.md` はメタ説明に固有の型だけを持ち、複製しない。
4. モードは2つ: 説明のみ（現状理解。変更計画・ミクロ計画・影響の節を省く）/ 変更前合意（7節フル）。
5. skill-visualizer の扱い: 廃止を提案。人間承認後に `skill-delete` ゲートで別途実施（catalog 2ファイル整理・symlink 5本撤去・deleted ログへ集約）。meta-explain の description からは skill-visualizer への否定トリガーを外し、「この仕組みを説明して」を発火語に加えて図解・理解用途を吸収する。
6. 本文ドラフト: 同フォルダの `skill本文ドラフト.md`（SKILL.md）と `説明の型ドラフト.md`（references）が正式ドラフト。実装時にコピーする（実装後の正本はskills側）。
7. 発火棲み分け: description に否定トリガー（軽い整理=naiyou-suriawase / 問い詰め=grill-me）を明記。
8. 安全方針: 対象ファイルを編集しない（読み取り＋Artifact公開のみ）。計画正本への反映は人間承認後。実装・削除・移動・symlink変更はどの段階でもしない。
9. runtime露出: Claude Codeのみ（Artifact依存のため）。他runtimeはローカルHTML出力対応を検討する未露出バックログとして作成ログに記載。
10. 実装手順（合意後）: `skills/meta-explain/`（SKILL.md＋references/説明の型.md）作成 → `SKILL.html` 生成 → `link-global-skill.sh` で `~/.claude/skills` へsymlink → `logs/created/2026-07/` 作成ログ → `catalog/meta.md` block追加 → 本計画を active 経由で done へ。skill-visualizer 廃止は承認が出た場合のみ、skill-delete の手順で別作業として実施。

## 完了条件（レビュー項目）

実装後、以下が全て満たされていれば done（skill-visualizer廃止は別手続きのため含めない）。

1. `AIエージェント基盤/skills/meta-explain/SKILL.md` が存在し、frontmatter `description` に日本語トリガー語（「メタ説明」「分かるまで説明」「この仕組みを説明して」）と否定トリガー（naiyou-suriawase・grill-me）が含まれる。
2. 同 `SKILL.md` 本文に「対象ファイルを編集しない（読み取り＋Artifact公開のみ）」「計画正本への反映は人間承認後」の安全方針が明記されている。
3. 同 `SKILL.md` は60行以内で、`skills/meta-explain/` 配下に `workflows/` が存在せず、`references/説明の型.md` が存在する。
4. `references/説明の型.md` に「説明の原則」「固定7節型」「見せ方マッピング」「理解ループ」の節があり、htmlスキル `html-structure.md` の部品ラダー・表条件を複製していない。
5. `skills/meta-explain/SKILL.html` が存在する。
6. `~/.claude/skills/meta-explain` が正本 `AIエージェント基盤/skills/meta-explain` への direct symlink である。
7. `global-skill-registry/logs/created/2026-07/` に meta-explain の作成ログがあり、`未露出バックログ:` 行に他runtimeの方針が書かれている。
8. `global-skill-registry/catalog/meta.md` に meta-explain の block があり、`近接・注意` に naiyou-suriawase / grill-me / html との棲み分けが書かれている。
9. 追加・変更ファイルに secret・token・credential・認証値の混入がない。

## 未決事項

全て回答済み（2026-07-11・人間OK）。

1. skill-visualizer を廃止してよいか → OK。同日 skill-delete ゲートで廃止済み（`logs/deleted/2026-07/07-11-skill-visualizer.md`）。
2. 名前は meta-explain で確定してよいか → OK。
3. 自発提案の可否と露出範囲 → OK（提案は可・発動は明示依頼のみ）。露出は同日の追加指示「スキルは基本全runtime露出」により全5runtimeへ変更。

## 結果（2026-07-11 実装完了）

1. 正本作成: `AIエージェント基盤/skills/meta-explain/`（SKILL.md 31行・`references/説明の型.md`・`SKILL.html`）。
2. 露出: 全5runtime（`~/.agents`・`~/.codex`・`~/.claude`・`~/.gemini/config`・`~/.gemini/antigravity-cli`）へ direct symlink。当初claudeのみの段階露出としたが、同日の人間指示で全露出へ変更し、作成ログの未露出バックログ行は解消。SKILL.mdにArtifact不可runtimeのローカルHTML代替を明記。
3. 登録: `logs/created/2026-07/07-11-meta-explain.md` 作成・`catalog/meta.md` へ block追加。
4. skill-visualizer 廃止: 正本フォルダ・runtime symlink 5本・migratedログを削除し `logs/deleted/2026-07/07-11-skill-visualizer.md` へ集約。`catalog/meta.md` の block削除・`catalog/applied.md` の html block文言更新。
5. レビュー項目: 9点すべて機械検証で充足。
6. 独立評価: Codex（gpt-5.6-terra・read-only exec直駆動）による `評価01.md` は FAILなし・CONCERN4件 → 同日 `修正01.md` で全て反映（発動条件の明文化・説明のみモードの①文言・大規模時の全文折りたたみ）。
