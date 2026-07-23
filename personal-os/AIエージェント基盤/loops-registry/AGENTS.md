# loops-registry — global loop の現役棚

ここは、複数repo/runtimeにまたがり、人の操作なしで時刻または間隔を発火点として繰り返す
**global loopの現役実装だけ**を置く場所。構想、手動コマンド、hook、廃止物を混ぜない。
`CLAUDE.md` はこの `AGENTS.md` への相対symlink。
`AGENTS.html` はこの文書を人が俯瞰するための派生説明であり、正本・AIの実行導線にはしない。

## loopの境界

- loop: 時刻または間隔で自動発火し、同じ責務を繰り返す処理。
- hook: runtimeイベント直後に動く処理。`../hooks-registry/` に置く。
- 手動コマンド: 所有Skillまたはrepoの `scripts/` に置く。
- AIの実装・レビュー・采配: Skill / orchestrationで行う。
- 構想・draft: 所有repoの `plans/` またはworktreeだけに置く。mainの `loops/` には置かない。

scopeは実装の所有属性。人間向け一覧では、追加先を迷わないよう「Personal OS」「仕事」の2領域で表示する。

- `global`: 複数repo/runtimeで共有するものを `loops/<loop名>/` に置く。
- `repo-local`: 特定repoの業務・資格情報に依存するものを所有repo内に置く。

repo-localの実装コピーはこの棚に置かない。人が見つける入口だけを `implementation-links/<repo-id>` として置き、
各所有repoの `loops/` root全体へ相対directory symlinkで繋ぐ。リンクの意味と安全規則は
`implementation-links/AGENTS.md` を正とし、実行・削除・正本判定にリンクを使わない。

runnerも属性として `loop.md` に書く。

- `script`: 決定的な機械処理を直接起動する。
- `ai`: 無人AI runtimeを起動する。人間の介入や方向修正があり得る処理はloopにせず、まずペイン実行で安定させる。

## 管理の構成と新規loopの最小構成

下の `<loop名>/` は新規作成時の契約である。既存loopにある `tests/`、`state/`、`output/` は移動・削除しない。

```text
loops-registry/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  AGENTS.html              人間向けの全体説明（派生物）
  loops/                  現役または30日以内に再開可能なglobal loop
    <loop名>/
      loop.md             目的・発火・runner・状態・停止手順
      *.plist             launchdを使う時だけの正本
      scripts/            実装が必要な時だけ
      logs/               ファイルログが必要な時だけ。gitignore
  implementation-links/   repo-local loop rootへの人間用入口（実体・実行経路ではない）
    AGENTS.md
    CLAUDE.md -> AGENTS.md
    仕事 -> projects/active/仕事/loops/
  実行loop一覧.md         自作loop全体のcurrent overview正本
  実行loop一覧.html       同じ内容の白基調・2領域ダッシュボード
  verify.py               global棚・全plist・MD・HTML整合検査
```

## 寿命

1. draftはplans/worktreeで育てる。
2. 目的・所有repo・発火条件・停止条件が解決し、テスト、plist検証、`実行loop一覧.md` 更新が揃ったらAIが `loops/` へ入れる。
3. 稼働中は `loop.md` と実体を一致させる。
4. 一時停止は `loop.md` とoverviewに停止理由・停止日・再判断期限を書く。再判断期限は停止日から最大30日で、期限切れを残さない。
5. 期限までに再開しなければ廃止する。廃止物のarchiveフォルダは作らず、Git履歴とdone計画を履歴正本にする。

## 変更・削除の安全手順

新設、発火条件変更、停止、再開、廃止は、対象・依存・復旧点を確認してAIが実行する。廃止は次の順序を崩さない。

1. `launchctl print gui/$(id -u)/<label>` で実機状態を確認する。
2. loadedなら `launchctl bootout gui/$(id -u)/<label>` する。
3. `~/Library/LaunchAgents/` と退避場所にある対象symlinkを除去する。
4. `rg` で現役loop、hook、Skill、plistからの実行依存を調べ、参照元を先に直す。
5. loop実体を削除する。削除対象を広げず、secretや実行ログを表示しない。
6. `実行loop一覧.md` を更新し、HTMLを再生成する。
7. `python3 verify.py` と関連テストを通す。

## state・lock・log

- 新規loopの定型作成は `loop.md` だけとする。`scripts/`、`logs/`、plistは必要な時だけ追加し、`tests/`・`state/`・`output/` を空フォルダとして作らない。既存loopの構成はこの変更だけで動かさない。
- state: 必要な永続stateは、そのloopが `loop.md` で明示したrepo外・DB・既存正本へ置く。汎用の `state/` は定型にしない。
- lock: 原則 `/tmp`。PIDとstale期限を持ち、二重起動を防ぐ。
- log: ファイルログが必要な時だけrepo外、またはgitignoreされた各loop内の `logs/` に置く。生ログを追跡しない。
- secret/token/credential: Keychain等のruntime保管だけを使い、plist・MD・HTML・ログ・Gitへ書かない。

## overview更新契約

目的、意図状態、発火条件、runner、launchd label、正本pathのいずれかが変わる時は、同じ変更で
`実行loop一覧.md` を更新する。内部実装だけの変更で一覧項目が変わらない場合は更新不要。
各loopは `領域` を必須とし、値は `Personal OS` または `仕事` の2つだけにする。
人間向け `発火` と機械可読JSON `発火設定` の両方を持つ。さらに起動後の順番を追える `内部処理`、
親子・専用・target分割を示す `launchd構成`、同周期loopを維持・統合する根拠を示す `統合判断` を必須とする。
一時停止時は停止理由・停止日・再判断期限を省略しない。

MD更新後は次を実行する。

```sh
python3 verify.py --write-html
python3 verify.py
```

`実行loop一覧.md` がAI向け正本、同basenameのHTMLは人間向け派生物。AIの実行導線からHTMLを参照しない。
`verify.py` PASSをloop構成変更の完了条件とする。

HTML生成時は `launchctl print` を読み、loaded・runs・last exitの実機スナップショットを埋め込む。
静的HTMLは常時liveではない。常時表示が必要な場合は、ページを開いている間だけlocalhost viewerが
launchctlをpollする方式を優先し、状態確認だけの短周期launchdをlabelごとに増やさない。
