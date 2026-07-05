# loop ランブック（loop 実行の標準）

このファイルは AIエージェント基盤の loop を「どう動かすか」の標準。個々の loop ではなく、全 loop 共通の契約と運用ルールを定める。フォルダ・ファイル名は英語、本文は日本語。

`loops-registry/references/` は loop 本体（`loops-registry/loops/<loop名>/`）ではなく、**全 loop 共通の参照置き場**。`references` という名前の loop は作らない。

**リファレンス実装（すでに本番稼働）**: `~/Private/projects/active/仕事/scripts/nextlevel-dispatcher/dispatcher.ts`。新しい dispatcher はこれを手本にする。

## 1. 全体モデル（launchd ＋ 軽量ディスパッチャ）

1. launchd の **1本の plist**（`StartInterval` 60秒、`RunAtLoad: true`）が、ディスパッチャを毎分起動する。PC 起動/wake 直後から動く。
2. **ディスパッチャ**（軽い script）は loop 一覧を読み、各 loop の `shouldRun()` で「今 due か」を判定する。**大半の分は何もしない**（毎分 AI を起動しない）。
3. due な loop だけ、`/tmp` の **PID＋stale ロック**で二重起動を確認してから、コマンドをバックグラウンド起動して即終了する。
4. 実行履歴（最終実行時刻など）は **state JSON** に記録する（repo外 or gitignore）。ディスパッチャ自身はリトライしない（失敗しても次の分に再判定）。

## 2. loop の契約（1 loop ＝ 1 タスク定義）

ディスパッチャは「コマンドを起動するだけ」。中身が何かは問わない。1 loop は次で定義する。

| 項目 | 意味 |
|---|---|
| `name` | loop 識別子 |
| `command` | due 時に起動するコマンド（中身は §3 の2系統） |
| `shouldRun()` | 起動条件（時間ベース／カレンダーベース） |
| `staleMs` | ロックの stale タイムアウト |
| `runner` | `ai` か `script`（§3） |

loop の稼働状態（`稼働中` / `停止` / `廃止`）は `loop.md` の frontmatter で持つ。

## 3. runner は2系統（基本この2つで動かす）

1. **`ai`**: `command` が AI runtime を起動する。Orca のオーケストレーション、または headless の Claude / Codex に、実装・計画・評価まで任せるプロンプトを渡す。AI 判断が要る loop はこれ。
2. **`script`**: `command` がスクリプトを直接実行する。決まった処理（例: 求人更新を gws で回す）はこれ。AI を噛ませない。

どちらも「ディスパッチャが起動するコマンド」という一点は同じ。loop ごとに `runner` を選ぶ。

## 4. loop の在処

- **global loop** → `基盤/loops-registry/loops/<loop名>/`（`loop.md`＋`scripts/`）。複数 repo・runtime で共通のもの。
- **repo-local loop** → 所有 `projects/<repo>/`（例: 仕事の求人更新）。その repo の業務・固有資格情報に依存するもの。判断は基盤 `AGENTS.md` §4（Global / repo-local）。
- ディスパッチャは両方を見て回す（将来のグローバル dispatcher で統合。今は各 repo の dispatcher が並走）。

## 5. state / lock / log の規約

- **state**（最終実行時刻など）: repo外 or gitignore。毎分 git を汚さない。
- **lock**: `/tmp/<dispatcher>-<loop>.lock` に PID＋開始時刻。プロセス生存確認＋stale タイムアウトで自動解放。
- **log**: repo外。生ログを repo に溜めない。
- **エラー/リトライ**: ディスパッチャは再判定で次の分に回す。個別 loop で必要なら `MAX_RETRY` を持つ。

## 6. 新しい loop を足す手順（概略）

1. global か repo-local か（§4）を決める。
2. `loop.md`（スペック）を書く。global なら `基盤/loops-registry/loops/<loop名>/`、repo-local なら所有 repo。
3. ディスパッチャの loop 一覧に `{name, command, shouldRun, staleMs, runner}` を登録する。
4. 動作確認（lock・state・due 判定）。

## 7. スコープ（現状）

- このランブックは**標準の定義**まで。グローバル dispatcher 本体の実装と、仕事リポの既存自動化の統合・移行は**別途**（仕事は今のまま動かす）。
- グローバル版を作る時に、リファレンス実装 `仕事/scripts/nextlevel-dispatcher/` を手本にして、このファイルを更新する。
