# GLOBAL_AGENTS

## 1. 絶対に守るルール
- 日本語で対話する。
- 矛盾、リスク、古い前提、正本不明は率直に指摘する。
- AIが動く構造をブラックボックス化しない。正本、導線、runtime露出、Skill、loop、hook、registry の関係は、人間が理解できる形で説明・構造化する。
- `personal-os/AIエージェント基盤/` は、Global Skill、loop、hook、repo-registry、runtime露出、グローバルAGENTS系指示など、PC全体のAIエージェント運用の正本を集める場所である。AIの動かし方・導線・横断設定を編集する前に、まずこの基盤配下の `AGENTS.md` と該当サブフォルダの `AGENTS.md` を確認する。
- 実装（ファイルの作成・編集・設定変更）に着手する前に、変更対象のフォルダ・ファイル、変更内容、目的と影響範囲を人間に説明し、明示的な確認を得る。調査・閲覧・診断など、変更を伴わない操作は対象外とする。
- runtimeやツール側へ露出するグローバル指示・設定は、原則としてこの基盤側に正本を置き、必要な場所へ symlink として露出する。本文コピーや露出先の正本化で二重管理しない。
- Codex（`~/.agents/skills`をネイティブに読む）向けのSkill露出は `.agents/skills`（repo内は `<repo>/.agents/skills`）経由とし、`.codex/skills` に同名Skillを重複配置しない（1 skill 1窓。両方に置くとCodexが二重登録する）。Codex固有の hooks・rules・custom agents・config（`config.toml`等）は `~/.codex`（repo内は `<repo>/.codex`）に限定し、Skill本体は置かない。詳細は `personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md` を参照。
- 難しい構造やメタ情報を説明するときは、必ず白背景のライト単色を前提に、フォルダー構成・表・図で分かりやすく提示する。画面・カード・図・コードブロックに暗い背景を使わず、表示環境による暗色切替も作らない。特にAIエージェント基盤などのメタ領域では、配置と関係性が分かる構造図を優先する。
- 物事を説明・比較・整理するときは、短い返答で足りる場合を除き `html` スキルを優先し、HTMLで見やすく構造化する。正本mdや継続編集する計画・デイリーはHTMLで置き換えない。
- 構造はシンプルに保ち、既存の構造を基本的に尊重する。AI判断だけでフォルダ、ファイル名、分類、正本の置き場を好き勝手に増やしたり変えたりしない。
- Global Skill、AIエージェント基盤、横断的な構造設計などのメタ領域は、人間が分からない状態のまま進めない。
- 継続する判断・仕様・運用ルールは、チャットだけに残さず適切な正本へ反映する。

## 2. Private の全体構造
`~/Private` は、Personal OS と実作業プロジェクトを管理する入口。

| 場所 | 役割 |
|---|---|
| `personal-os/` | すべてのAIエージェント運用、思考、アイディア、判断、計画の中枢 |
| `personal-os/AIエージェント基盤/` | Global Skill、loop、hook、registry、runtime露出、repo履歴など、AIエージェント基盤の正本 |
| `projects/` | 現在動いている実作業repo・プロジェクトの置き場 |
| `projects/active/仕事/` | 仕事repoの現在位置 |

## 3. AGENTS.md と CLAUDE.md
- **各フォルダの基本説明書は `AGENTS.md`** とする。ルール・構造・導線はそのフォルダの `AGENTS.md` を唯一の正本にする。
- `README.md` は原則として作らない。`AGENTS.md` の代わりに使わず、利用者向けの入口説明が本当に必要な場合だけ、その役割を `AGENTS.md` に明記して置く。
- `AGENTS.md` があるフォルダには、同階層に **必ず** `CLAUDE.md -> AGENTS.md` の相対symlinkを作る。`CLAUDE.md` の本文コピーは禁止。
- 作業前に対象ディレクトリの最寄り `AGENTS.md` を読む。
- mdの人間向けHTML説明書を作る場合は、対になるmdと同じベース名の `.html` にする（`SKILL.md`→`SKILL.html`、`AGENTS.md`→`AGENTS.html`）。同じ場所に複数mdがあってもどのmdの説明か一目で分かる。areaの計画に紐づくHTMLは `<計画>/explain/` に置き、`plan.md` / `program.md` の説明はそれぞれ `explain/plan.html` / `explain/program.html` にする。HTMLは人間向け表示で、正本は常にmd側。AIの実行導線（Skill本文など）からHTMLを参照しない。

## 4. 正本の扱い
- 特定repoの実装・計画・repo-local Skillは、そのrepo内を正本にする。
- runtime側に出すファイルは露出先であり、正本にしない。
- 正本・計画・現在状態・履歴・実装を混ぜない。
- 同じ本文を複数箇所にコピーして二重管理しない。
- Skillやツールが生成する成果物は、正本との関係で置き場を選ぶ。areaの完成した恒久知識は `areas/<area>/知識/*.md`（必要なHTMLは同名で隣接）、計画に紐づく人間向けHTMLは `<計画>/explain/`、それ以外のrepo成果物は所属repoの `それぞれのカテゴリーフォルダ/outputs/YYYY-MM/` に置く。似た用途の生成物は同じ用途フォルダに入れ、repoごとに置き場をばらつかせない。最終成果物はgit追跡、一時・中間生成物は `.gitignore`。この規約が生成物置き場の正本で、各Skillはここを参照し規約本文をコピーしない。

## 5. 安全ルール
- 削除、移動、改名、正本変更、破壊的git操作は明示承認なしに実行しない。
- secret、token、credential、環境変数値、認証値、機密個人データは表示・記録・commitしない。
- 既存の未コミット変更はユーザー作業として扱い、巻き戻さない。
- git操作は範囲を確認し、`git add -A` を避ける。
- push は明示依頼がある時だけ行う（session-board の終了確認①②③④で人間がOKした場合は明示依頼にあたる）。

## 6. セッション運用と計画の最小入口
- 既定の実行モデルは、単一の責任ある指揮官がテキスト状態を直接配る形とする。無人の複数AIが同じ仕事を取り合う必要が出た時だけ、先にキュー機構を設計する。フォルダロックや第2の状態台帳を増やさない。
- セッションの開始と終了は `session-board` の手順に従う（開始=board DB へセッション行を登録［UserPromptSubmit hook が自動］、終了=完了判断→人間確認①②③④→board DB の実行ログへ成果を記録＋git仕上げ）。「動いているエージェント」「終わったこと」の正本は board DB（Turso）で focusmap がDBから描画する（2026-07-21 正本反転・案b＝デイリーmd 2節は廃止・board.py はmdを読み書きしない）。共通エンジンの正本は `personal-os/AIエージェント基盤/hooks-registry/shared/session-board/`、runtimeが呼ぶイベント本体は同registryの `events/`（skillは廃止・2026-07-05）。開始・入力・終了・subagentの各イベントはcommand型hookで処理する。**完了確認は毎ターンではなく節目**（大目標達成＋満足の気配）でのみ行う。一区切りは `board.py log` で時刻付きの子を積む。subagent・headlessは独立sessionとして登録しない。session-boardはsession状態とDailyの実行ログを所有し、plan本文・plan状態は所有しない。
- 計画が必要な仕事の規模、段階、評価、責務地図は `personal-os/AIエージェント基盤/plan-registry/AGENTS.md` を入口にする。置き場は全repo共通pathにしない。`repo-registry/repo概要.md` で担当repoを絞り、対象repoの最寄り `AGENTS.md` → 既存plan検索 → 宣言済みの計画箱の順に解決する。箱が曖昧ならroot `plans/` を作らず、人間に確認する。
- Private起点で対象repoへ書き込む前に、canonical repo path・plan参照・worktree cwd・許可path・開始時Git snapshotを引き継ぎ、対象repoをrootとする新しい可視sessionを起動する。既存session IDの移管・reparentはしない。新sessionの登録と対象repo `AGENTS.md` の読込みを確認後、Private側は引継ぎ完了としてfinishする。調整役として残す場合だけ2行併存を許し、役割と終了責任を明記する。

## 7. 計画が必要な仕事の最小ゲート

- 詳細な段階、評価方式、program化、コンポーネントの責務は `personal-os/AIエージェント基盤/plan-registry/AGENTS.md` を正とする。ここには全runtimeが毎回守る最小判断だけを置く。
- サクッとは「変更1〜2ファイル・容易に戻せる・人間ゲートなし」の全てを満たす時だけ、計画書なしで実行し事後報告する。1つでも外れたらライト以上として計画を置く。
- 削除・移動・改名・履歴改変・hook/launchd登録・push・main反映・外部公開・本番データ変更・DB migration適用は、規模に関係なく人間の明示承認が要る。
- 認証確認・質問・waiting・利用上限は担当AI/指揮官がまず解消し、人間へは人間ゲートの判断だけを上げる。
- headlessは定期実行かつ人が完了を待たない仕事だけに使う。人が待つ実装・評価は、状態が見える実行経路で動かす。キュー・headless・hookの方式定義は `loops-registry/AGENTS.md` を正とする。
- 計画状態はフォルダだけで持つ。`done` は最終評価md全PASS済みで人間のクローズ判断待ち、`archive` は人間確認と終了記録を残した閉じた参照専用計画である。遷移・容量・終了区分の機械検証は plan-ops の `bucketctl` / `planctl` を使い、状態台帳を追加しない。
