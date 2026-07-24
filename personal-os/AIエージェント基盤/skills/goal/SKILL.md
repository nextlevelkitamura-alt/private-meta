---
name: goal
description: 完遂実行ゲート＝目的と完了条件が定まった仕事を「打てば done まで走らせる」実行コマンド。/goal <テーマ|計画> で theme.md の完成形スケッチと検証可能ゴールを確認し、無ければ実装に入らず壁打ち(grill-me)へ差し戻す。あれば実行ライン方式(テンプレv3)で planning 起票→active 昇格→上から直列に自律実行→[SAVE]でまとめ評価1回→done まで運ぶ。Use when 人間が「goal」「/goal」「これ完遂まで走らせて」「一気通貫でやって」「目的は決まったから実装まで回して」と、合意済みの目的を実行フェーズへ渡す時。やりたいこと1件の起票だけなら kickoff、計画の作成・合流・評価・終了の管理入口は plan-create-review を使う（goalはそれらを呼ぶ実行driverで、規約・評価合否・close判定を再定義しない）。
---

# goal（完遂実行ゲート）

「何を作るか合意してから作る」をコマンドの構造で強制し、合意後は人手の逐次指示なしに done まで運ぶ実行driver。実装ファーストに走りやすいAI（特にCodex）向けに、入場条件で完成形の合意を必須化する。

正本ポインタ（本文に複製しない）:

- テーマ層（themes/・theme.md 6節・完成形スケッチ・ハイブリッド共存・テーマ連動クローズ）: `~/Private/personal-os/my-brain/areas/AGENTS.md` §1.2
- 実行ライン方式(テンプレv3)・[SAVE]評価・Program例外: 同 §3 と `~/Private/personal-os/AIエージェント基盤/plan-registry/AGENTS.md` §2
- 規模・自律実行と停止条件（危険操作の人間ゲート）: `~/Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md` §5–7
- 計画の機械手続き（`bucketctl promote`・`new-plan.sh` v3・lint）: skill `plan-ops`
- 壁打ち: skill `grill-me`（入場条件の差し戻し先）／`naiyou-suriawase`

## 手順（合意 → 完遂まで一直線）

0. **入場条件（実装ファースト制御）**: 対象テーマの theme.md に「完成形スケッチ」と検証可能なゴールがあるか確認する。無い／「未確定」のままなら**実装に入らず** grill-me へ差し戻す（何を作るか合意してから作る）。
1. **目的の読取**: `/goal <テーマ|計画>` で theme.md（board-theme-id で board DB の名前・状態も取得）を読む。完了条件が曖昧なら grill-me を**3問以内**で挟んで確定する。それ以上は聞かず仮置きして進み、仮置き点を計画の「記録」に残す。
2. **計画の確保**: 対象の計画が無ければ実行ライン方式(テンプレv3)で planning に起票（plan-ops `new-plan.sh`）→ `bucketctl promote --to active` で昇格する。planning／active 上限に当たったら人間へ1行で裁定を仰ぐ（planning のまま実装先行はしない）。既存計画があれば合流する。
3. **直列自律実行**: 実行ラインを上から直列に自律実行する。並列区間（`⇉`）だけ subagent へ fan-out し、合流ステップで統合する。
4. **[SAVE]評価**: `[SAVE]` 到達時にまとめ評価1回 → FAIL なら修正1回 → 再評価 → 再FAIL のみ人間へエスカレーション（差し戻し上限1・plan-registry §2）。評価は `評価/まとめ評価RR.md` に記録する。
5. **done**: 完了条件を照合し全達成なら done へ。人間ゲートは GLOBAL_AGENTS §7 の危険操作（削除・push・本番反映・DB migration 等）だけに限定する。
6. **テーマ更新**: 完了時に theme.md の「派生計画」を更新し、テーマのゴールが全達成ならテーマの `_closed/` へのクローズを人間に提案する（テーマ連動クローズ・areas §1.2）。

## 役割分担（近接ゲートと重複させない）

1. **kickoff = 起票**（やりたいこと1行をインボックスへ・軽量判定）。goal はその後の実行フェーズを担う。
2. **plan-create-review = 計画管理の入口**（作成／合流／program／評価／終了への振り分け）。goal は計画を done まで走らせる実行driver で、評価合否・close 判定・route 基準を再定義せず plan-registry／plan-ops を呼ぶ。
3. goal 自身は規約・script・計画本文を所有しない（正本は上記ポインタ）。

## 安全方針

1. 副作用: 計画の作成・昇格・実装・評価・done 遷移まで自律実行する（依頼範囲内）。goal はユーザーが `/goal` で呼んだ時だけ動き、それ自体は常駐しない。
2. 人間ゲート: GLOBAL_AGENTS §7 の危険操作（削除・force push・本番／DB 反映・外部公開・別権限）と、入場条件を満たさない実装だけを止める。
3. 禁止: 完成形スケッチ未確定のまま実装に入ること。planning のまま実装先行すること。git 未追跡の他者WIP を無断で移動・改変すること。
