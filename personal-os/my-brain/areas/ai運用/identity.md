# ai運用 Identity

## 目的

personal-os 基盤、Global Skill、repo、loop、CLI（Orca など）の運営に関する考えと計画を整理する。
このareaは「考え・計画」を持つ。実装の正本は持たない。

## 実装正本との違い（混同しない）

1. このarea（`my-brain/areas/ai運用/`）: 基盤をどう運営するかの考えと計画。
2. 実装正本（`personal-os/AIエージェント基盤/`）: Skill本文、registry、logs、runtime露出の正本。
3. 名前が似ているが別物。計画はこのarea、実装はAIエージェント基盤に置く。

## 判断基準

1. 具体的な実行に進む前に、目的、前提、完了条件を明確にする。
2. 人間が判断すること、AIに任せること、repoやSkillやloopに落とすことを分ける。
3. 計画本文は `plans/<バケット>/<計画名>/plan.md` を正本にする（状態はバケットで持つ）。
4. 実装正本（Skill本文、registry、logs）はこのarea内に増やさない。

## 置くもの

1. personal-os 自体の構造・運用ルールの検討。
2. Global Skill、repo、loop、CLI（Orca など）の企画・計画。
3. 旧計画ディレクトリから移行済みの基盤・横断計画。

## 置かないもの

1. secret、token、credential、環境変数の値。
2. Skill本文、registry、logs（`../../../AIエージェント基盤/` が正本）。
3. 実装repo本体（`/Users/kitamuranaohiro/Private/projects/` に置く）。
