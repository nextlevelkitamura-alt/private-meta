# Codex Hooks 実務リファレンス

Codex CLI の hooks をカスタマイズするための恒久リファレンス。
今後同じ調査を繰り返さないよう、公式ドキュメントとローカル確認結果を整理したもの。

> 対象範囲: 2026-07-05 時点、`codex-cli 0.142.5` で確認。
> Codex は変化が速いため、細かい仕様は実装前に公式ドキュメントで再確認すること。

## 1. 概要

Codex には、ライフサイクルに処理を差し込む仕組みが2つある。

- `hooks`: セッション開始、ユーザープロンプト送信、ツール使用前後、停止、サブエージェント、圧縮前後など、複数イベントに応じてコマンドを実行できる仕組み。コンテキスト注入や、処理のブロック・誘導ができる。
- `notify`: ターン完了時だけに発火する軽量通知。基本的に外部通知向けで、出力は無視される。

## 2. hooks と notify の使い分け

イベントごとの情報を取りたい、Codex に文脈を注入したい、処理を止めたり誘導したい場合は `hooks` を使う。

単に「1ターン終わった」ことを外部通知したいだけなら `notify` で足りる。ただし `notify` は1枠しかなく、既に別クライアントに使われている場合がある。

入出力も違う。`hooks` は stdin から JSON を読み、stdout に JSON を返せる。`notify` は JSON を argv[1] で受け取り、出力は無視される。

## 3. 主なイベント

- `SessionStart`: セッション開始、再開、クリア、圧縮後の再開。
- `UserPromptSubmit`: ユーザーがプロンプトを送信した時。
- `PreToolUse`: Bash、`apply_patch`、MCPツールの実行前。
- `PermissionRequest`: Codex が権限承認を求める時。
- `PostToolUse`: ツール実行後。
- `SubagentStart`: サブエージェント開始時。
- `SubagentStop`: サブエージェント停止時。
- `Stop`: メインターン停止時。
- `PreCompact` / `PostCompact`: 会話圧縮の前後。

## 4. command hook の入力仕様

現在実行されるのは `type: "command"` の hook のみ。`prompt` や `agent` は解析されるが実行されない。`async` もまだ未対応。

hook コマンドは、そのセッションの `cwd` を作業ディレクトリとして実行される。

入力は stdin に渡される1つの JSON オブジェクト。共通フィールドには `session_id`、`transcript_path`、`cwd`、`hook_event_name`、`model`、`permission_mode` などがある。

終了コードは、`0` が成功、`2` がブロック、その他の非ゼロが hook エラー。終了コード `2` の場合、stderr の内容が理由として扱われる。

環境変数で情報が渡る前提は置かず、stdin の JSON を読む。

```python
import sys, json
d = json.load(sys.stdin)
sid, cwd = d["session_id"], d["cwd"]
```

## 5. 出力と制御

hook は stdout に JSON を返せる。

コンテキスト注入には `additionalContext` または `systemMessage` を使う。

処理を止めたり誘導したい場合は、`continue: false` と `stopReason` を返す。古い形式として `decision: "block"` と `reason` もある。終了コード `2` と stderr でもブロックできる。

注意点として、`Stop` と `SubagentStop` はブロックや継続判断はできるが、`additionalContext` や `systemMessage` は注入できない。文面を返したい場合は `stopReason` / `reason` 経由にする。

## 6. 設定の読み込み順

hooks は次の順で読み込まれる。上位が下位を置き換えるのではなく、条件に一致する hook はすべて実行される。

1. `~/.codex/hooks.json`
2. `~/.codex/config.toml` の `[hooks]`
3. `<repo>/.codex/hooks.json`
4. `<repo>/.codex/config.toml` の `[hooks]`
5. plugin 同梱の hooks

同じ層に `hooks.json` と `[hooks]` の両方がある場合、警告付きで両方読み込まれる。

`matcher` は正規表現。省略、空文字、`*` は全一致。ツール系イベントでは `Bash` などのツール名に対してマッチする。

`hooks.json` の形:

```json
{ "hooks": { "SessionStart": [ { "matcher": "startup|resume",
  "hooks": [ { "type": "command", "command": "python3 ~/.codex/hooks/x.py",
              "statusMessage": "...", "timeout": 600 } ] } ] } }
```

TOML で書く場合:

```toml
[[hooks.SessionStart]]
matcher = "startup|resume"
[[hooks.SessionStart.hooks]]
type = "command"
command = "python3 ~/.codex/hooks/x.py"
timeout = 600
```

## 7. 有効化と信頼

hooks は `[features] hooks = true` で有効になる。デフォルトは有効。`false` にすると全 hook が無効になる。

管理外の command hook は、実行前に Codex 側で確認・信頼登録が必要。信頼状態は hook のハッシュに紐づくため、hook を変更すると再レビューが必要になる。

確認と信頼登録は `/hooks` コマンドで行う。信頼状態は `~/.codex/config.toml` の `[hooks.state]` に保存される。

## 8. notify

`notify` は `config.toml` に `notify = ["program", "arg", ...]` として設定する。

発火するのは `agent-turn-complete` のみ。payload は stdin ではなく argv[1] に JSON として渡される。

このマシンでは notify 枠が Computer Use client に使われている可能性がある。そのため、競合を避けるなら `notify` より `Stop` hook を優先した方がよい。

```python
import sys, json
n = json.loads(sys.argv[1])
```

## 9. 注意点

- 現状は command hook のみ。Claude の prompt 型 hook のように、モデル判断で hook を動かす仕組みはない。
- `Stop` ではコンテキスト注入できない。誘導するなら `stopReason` / `reason` を使う。
- ツール hook が拾うのは Bash、`apply_patch`、MCPツールなど。通常のファイル書き込みすべてを拾えるわけではない。
- hook を編集するたびに `/hooks` で再信頼が必要。
- `notify` はターン完了通知専用で、出力は無視される。

## 10. 実装例の意味

`~/.codex/hooks.json` に `SessionStart`、`UserPromptSubmit`、`Stop` の3つを登録すれば、セッション開始時、ユーザー入力時、ターン停止時にそれぞれ Python スクリプトを実行できる。

スクリプト側では stdin の JSON を読み、必要なら `additionalContext` を返して Codex に作業ルールやワークスペース文脈を注入する。

また、`SubagentStart` と `SubagentStop` を使えば、バックグラウンドでサブエージェントが動いている状態を記録できる。複数サブエージェントが同時に動く可能性があるため、`agent_id` を使って参照カウントするのがよい。

## 11. 参照元

- 公式: Codex Hooks: https://developers.openai.com/codex/hooks
- 公式: Advanced config / notify: https://developers.openai.com/codex/config-advanced
- ローカル確認: `~/.codex/config.toml`、`codex --help`
- 確認日: 2026-07-05
