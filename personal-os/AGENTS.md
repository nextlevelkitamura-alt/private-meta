# Personal OS

このディレクトリは、AIエージェント運用基盤、my-brain、計画、進捗、優先順位、意思決定を置く中枢。
実装repoではなく、AI作業を迷わず進めるための業務運用repoとして扱う。

> **まず読む（現在の運用モデル）**: 使い方・構造・状態の持ち方の入口は `説明書/README.md`。
> 今は「コックピット方式（Orca で計画/実装/レビューを直接指揮）＋ 状態2モード（既定=テキスト状態B・ai-jobs フォルダ受け渡しは保留）」で運用。会話をまたぐ前提はここに残す。

## 1. この場所でやること

1. AIエージェント運用基盤の正本を管理する。
2. my-brainで、自分の考え、領域ごとの判断軸、調査、計画を管理する。
3. Global Skill、repo registry、runtime露出、計画、履歴の置き場を整理する。
4. Personal OS基盤、横断repo、Global Skill、loopの企画・計画を管理する。
5. 実行済みの事実、これからやる判断、現在状態を混ぜずに分ける。
6. 特定repoの実装やrepo-local Skill計画は、そのrepo側を正本にする。

## 2. 絶対ルール

1. 削除、移動、履歴整理、repo改名、正本変更は人間の明示承認なしに実行しない。
2. `CLAUDE.md` は同階層の `AGENTS.md` への相対symlinkにする。本文コピーは禁止。
3. `personal-os/` 直下に、新しい正本フォルダや作業場を勝手に増やさない。
4. 新しいrepo本体は原則として `/Users/kitamuranaohiro/Private/projects/` 配下に置く。
5. repoの現在状態は `/Users/kitamuranaohiro/Private/projects/{active,paused,archive}/` の実体配置を正とする。
6. `my-brain/areas/`、`AIエージェント基盤/`、各repoの `plans/` に同じ内容を二重管理しない。
7. secret、token、credential、環境変数の値は表示・記録・commitしない。
8. フォルダ構成、正本、計画、registry、logs、runtime露出を変更した場合は、関連する `AGENTS.md` / `CLAUDE.md` / plans / logs / catalog の整合性を同じ作業単位で確認・更新する。
9. 構成やルールを変更したまま、エージェント向け入口説明を古い状態で放置しない。
10. 忖度しない。矛盾、盲点、リスクは率直に指摘する。

## 3. フォルダ概要

1. `AGENTS.md`: personal-os入口ルールの正本。
2. `CLAUDE.md`: `AGENTS.md` への相対symlink。本文コピーは禁止。
3. `my-brain/`: 自分の考え、領域ごとの判断軸、調査、計画。
4. `AIエージェント基盤/`: Global Skill正本、Global Skill registry、repo履歴ログ、runtime露出補助。
5. `説明書/`: 現在の運用モデル・使い方の入口ドキュメント（`README.md`）。会話をまたぐ前提を残す場所。

### git構造（コミット前に必ず把握）

1. `~/Private` 全体が1つのgit repo（branch `main`、remote: GitHub private `nextlevelkitamura-alt/private-meta`）。`personal-os/my-brain/` 等を追跡する。
2. `AIエージェント基盤/` は別の独立git repo（別branch・非公開(private)のGitHub remote）で、`~/Private` 側からは `.gitignore` で非追跡。二重管理は起きていない。
3. 1論理変更が2repoにまたがることがある（例: plans廃止→ai運用一本化）。各repoで別々にコミットし、本文で相手repoの変更に言及して束ねる。
4. コミット前に確認する: `main` 直コミットか作業branchか、`git add -A` を避けてパス指定、secret混入、push可否（push は明示依頼時のみ）。

## 4. 大事にする価値観

1. 正本を一つにする。コピーや二重管理で安心しない。
2. 計画、現在状態、履歴、実体を混ぜない。
3. まず既存構造を読む。思いつきでフォルダや分類を増やさない。
4. 迷ったら、どこを正本にするかを先に決める。
5. 長い手順や過去ログを `AGENTS.md` に溜め込まない。
6. 人間が1分で説明できない構成にしない。
7. 人間が読んで分かりづらい構成、名前、説明にしない。
8. 書き方は端的に、具体的に、作業者が次に何をすればよいか分かる形にする。
9. 抽象語でごまかさず、必要なら「どこに置く」「何をしない」「何を確認する」まで書く。

## 5. 作業の始め方

1. まずこの `AGENTS.md` を読む。
2. my-brainを触る場合は `my-brain/AGENTS.md` を読む。
3. 領域別の考えや計画を触る場合は `my-brain/areas/AGENTS.md` と対象areaの `AGENTS.md` を読む。
4. AIエージェント基盤を触る場合は `AIエージェント基盤/AGENTS.md` を読む。
5. Personal OS基盤、Global Skill、repo、loopの計画を触る場合は `my-brain/areas/AGENTS.md` と `my-brain/areas/ai運用/AGENTS.md` を読む。
6. 特定repoに関わる場合は、そのrepoの `AGENTS.md` を読む。
7. 作業前に対象の正本、履歴、現在状態の置き場を確認する。
8. 新しいディレクトリを増やす場合は、同じ作業でこのファイルのフォルダ概要に役割を追加する。
9. `AGENTS.md` を作成または同梱する場合は、同階層の `CLAUDE.md -> AGENTS.md` を確認する。

## 6. 更新ルール

1. 領域別の考え、調査、判断軸、実行計画は `my-brain/areas/` に置く。
2. 領域別計画は `my-brain/areas/<area>/plans/<バケット>/<計画名>/plan.md` を正本にする（状態はバケット）。計画は area で育て、成熟したら実行repoへ卒業させる（流れの正本は `my-brain/areas/AGENTS.md` の §5）。計画の状態バケット語彙（`planning`/`ready`/`active`/`paused`/`done`/`archive`）は area と `AIエージェント基盤/` 共通で `my-brain/areas/AGENTS.md` §4 が正本。global skill 計画の卒業先は `AIエージェント基盤/global-skill-registry/plans/`、loop 計画は `AIエージェント基盤/loops-registry/plans/loop/`（構成は同 repo `AGENTS.md` §1.1）。
3. 計画から派生する作業の置き場は `my-brain/areas/AGENTS.md` §4.2 を正とする（AI実行はai-jobs run-cardまたはモードBの指揮官テキスト状態、human作業はprogram.mdマップ／子.md。旧 `ops/` 5フォルダ構成は廃止・既存はlegacy）。段階語彙・人間ゲートは `説明書/運用契約.md` §2。
4. Personal OS基盤、横断repo、Global Skill、repo、loopの計画は `my-brain/areas/ai運用/plans/active/<YYYY-MM-DD-日本語企画名>/plan.md` に置く（状態はバケットで移す）。
5. 実行済みの事実、移動、削除、改名、登録の履歴は該当registryの `logs/` に短く残す。
6. Global Skillの正本は `AIエージェント基盤/skills/`、Global loop の正本は `AIエージェント基盤/loops-registry/loops/` に置く。
7. Global Skillの索引は `AIエージェント基盤/global-skill-registry/catalog/` に置く。
8. repo単位の登録、移動、削除、repo-local Skill履歴は `AIエージェント基盤/repo-registry/logs/` に置く。
9. 特定repoの計画やrepo-local Skill計画は、そのrepo内の `plans/` に置く。
10. 完了済みの計画には、結果と反映先だけを短く追記する。
11. 同じルールを `AGENTS.md`、README、plans、logs、catalogに重複して書かない。

## 7. 確認方法

1. フォルダ構成が `AGENTS.md` の説明と一致している。
2. `CLAUDE.md` が相対symlinkになっている。
3. 計画と履歴と現在状態が混ざっていない。
4. 不要な新規フォルダ、コピー、二重管理が増えていない。
5. 危険操作が必要な場合、人間の明示承認がある。
