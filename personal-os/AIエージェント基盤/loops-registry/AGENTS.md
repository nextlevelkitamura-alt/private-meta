# loops-registry — global loop の現役棚

ここは、複数repo/runtimeにまたがり、人の操作なしで時刻または間隔を発火点として繰り返す
**global loopの現役実装だけ**を置く場所。構想、手動コマンド、hook、廃止物を混ぜない。
`CLAUDE.md` はこの `AGENTS.md` への相対symlink。

## loopの境界

- loop: 時刻または間隔で自動発火し、同じ責務を繰り返す処理。
- hook: runtimeイベント直後に動く処理。`../hooks-registry/` に置く。
- 手動コマンド: 所有Skillまたはrepoの `scripts/` に置く。
- AIの実装・レビュー・采配: Skill / orchestrationで行う。
- 構想・draft: 所有repoの `plans/` またはworktreeだけに置く。mainの `loops/` には置かない。

scopeは属性であり、種類別フォルダは作らない。

- `global`: 複数repo/runtimeで共有するものを `loops/<loop名>/` に置く。
- `repo-local`: 特定repoの業務・資格情報に依存するものを所有repo内に置く。

runnerも属性として `loop.md` に書く。

- `script`: 決定的な機械処理を直接起動する。
- `ai`: 無人AI runtimeを起動する。人間の介入や方向修正があり得る処理はloopにせず、まずペイン実行で安定させる。

## 現在の構成

```text
loops-registry/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  loops/                  現役または30日以内に再開可能なglobal loop
    <loop名>/
      loop.md             目的・発火・runner・状態・停止手順
      *.plist             launchd正本（1本以上）
      scripts/            実装
  実行一覧/
    AGENTS.md
    CLAUDE.md -> AGENTS.md
    personal-os.md        current overviewの正本
    personal-os.html      同じ内容の人間向け表示
    verify.py             実体・plist・MD・HTML整合検査
```

## 寿命

1. draftはplans/worktreeで育てる。
2. 人間GO、テスト、plist検証、`実行一覧/personal-os.md` 更新が揃ってから `loops/` へ入れる。
3. 稼働中は `loop.md` と実体を一致させる。
4. 一時停止は `loop.md` とoverviewに停止理由・停止日・再判断期限を書く。再判断期限は停止日から最大30日で、期限切れを残さない。
5. 期限までに再開しなければ廃止する。廃止物のarchiveフォルダは作らず、Git履歴とdone計画を履歴正本にする。

## 変更・削除の安全手順

新設、発火条件変更、停止、再開、廃止は人間ゲート。廃止は次の順序を崩さない。

1. `launchctl print gui/$(id -u)/<label>` で実機状態を確認する。
2. loadedなら `launchctl bootout gui/$(id -u)/<label>` する。
3. `~/Library/LaunchAgents/` と退避場所にある対象symlinkを除去する。
4. `rg` で現役loop、hook、Skill、plistからの実行依存を調べ、参照元を先に直す。
5. loop実体を削除する。削除対象を広げず、secretや実行ログを表示しない。
6. `実行一覧/personal-os.md` を更新し、HTMLを再生成する。
7. `python3 実行一覧/verify.py` と関連テストを通す。

## state・lock・log

- state: repo外、またはgitignoreされた各loop内の `state/`。実行のたびにGitを汚さない。
- lock: `/tmp` またはgitignoreされたstate。PIDとstale期限を持ち、二重起動を防ぐ。
- log: repo外、またはgitignoreされた各loop内の `output/logs/`。生ログを追跡しない。
- secret/token/credential: Keychain等のruntime保管だけを使い、plist・MD・HTML・ログ・Gitへ書かない。

## overview更新契約

目的、意図状態、発火条件、runner、launchd label、正本pathのいずれかが変わる時は、同じ変更で
`実行一覧/personal-os.md` を更新する。内部実装だけの変更で一覧項目が変わらない場合は更新不要。
人間向け `発火` と機械可読JSON `発火設定` の両方を持ち、一時停止時は停止理由・停止日・再判断期限を省略しない。

MD更新後は次を実行する。

```sh
python3 実行一覧/verify.py --write-html
python3 実行一覧/verify.py
```

`personal-os.md` がAI向け正本、同basenameのHTMLは人間向け派生物。AIの実行導線からHTMLを参照しない。
`verify.py` PASSをloop構成変更の完了条件とする。
